import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

const marker = 'DEJANK_METER ';

Future<void> measure(String name, Future<void> Function() body) async {
  final builds = <String, int>{};
  final frames = <FrameTiming>[];
  final previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    final type = element.widget.runtimeType.toString();
    builds[type] = (builds[type] ?? 0) + 1;
    previous?.call(element, builtOnce);
  };
  void onTimings(List<FrameTiming> timings) => frames.addAll(timings);
  SchedulerBinding.instance.addTimingsCallback(onTimings);
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = previous;
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
  }

  void report(Map<String, Object> line) => print('$marker${jsonEncode({'name': name, ...line})}');
  for (final MapEntry(key: widget, value: count) in builds.entries) {
    report({'widget': widget, 'builds': count});
  }
  if (frames.isNotEmpty) report({'frames': summarize(frames)});
}

void Function() live({String name = 'live', Duration every = const Duration(seconds: 1)}) {
  WidgetsFlutterBinding.ensureInitialized();
  final builds = <String, int>{};
  final sent = <String, int>{};
  final frames = <FrameTiming>[];
  var reported = 0;
  final previous = debugOnRebuildDirtyWidget;
  debugOnRebuildDirtyWidget = (element, builtOnce) {
    final type = element.widget.runtimeType.toString();
    builds[type] = (builds[type] ?? 0) + 1;
    previous?.call(element, builtOnce);
  };
  void onTimings(List<FrameTiming> timings) => frames.addAll(timings);
  SchedulerBinding.instance.addTimingsCallback(onTimings);
  void report(Map<String, Object> line) => print('$marker${jsonEncode({'name': name, ...line})}');
  report({'ready': true});
  final timer = Timer.periodic(every, (_) {
    for (final MapEntry(key: widget, value: count) in builds.entries) {
      if (sent[widget] == count) continue;
      sent[widget] = count;
      report({'widget': widget, 'total': count});
    }
    if (frames.length != reported && frames.isNotEmpty) {
      reported = frames.length;
      report({'frames': summarize(frames)});
    }
  });
  return () {
    timer.cancel();
    debugOnRebuildDirtyWidget = previous;
    SchedulerBinding.instance.removeTimingsCallback(onTimings);
  };
}

Map<String, Object> summarize(List<FrameTiming> frames) {
  double ms(Duration d) => d.inMicroseconds / 1000;
  double avg(double Function(FrameTiming) f) => frames.map(f).reduce((a, b) => a + b) / frames.length;
  const budget = 1000 / 60;
  return {
    'count': frames.length,
    'buildMs': avg((f) => ms(f.buildDuration)),
    'rasterMs': avg((f) => ms(f.rasterDuration)),
    'slow': frames.where((f) => ms(f.buildDuration) > budget || ms(f.rasterDuration) > budget).length,
  };
}
