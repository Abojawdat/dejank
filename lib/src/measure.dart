import 'dart:convert';

const marker = 'DEJANK_METER ';

class Run {
  final Map<String, int> builds;
  Map<String, num>? frames;

  Run(this.builds, [this.frames]);

  factory Run.fromJson(Map<String, dynamic> json) =>
      Run(Map<String, int>.from(json['builds'] as Map), (json['frames'] as Map?)?.cast<String, num>());

  Map<String, Object> toJson() => {'builds': builds, 'frames': ?frames};

  int get total => builds.values.fold(0, (a, b) => a + b);
}

Map<String, Run> parseRuns(Iterable<String> lines) {
  final runs = <String, Run>{};
  for (final line in lines) {
    final i = line.indexOf(marker);
    if (i == -1) continue;
    final record = jsonDecode(line.substring(i + marker.length)) as Map<String, dynamic>;
    final run = runs.putIfAbsent(record['name'] as String, () => Run({}));
    if (record['widget'] case final String widget) {
      run.builds[widget] = (run.builds[widget] ?? 0) + (record['builds'] as int);
    }
    if (record['frames'] case final Map frames) run.frames = frames.cast();
  }
  return runs;
}

String table(String name, Run? before, Run now) {
  final out = StringBuffer();
  void row(String label, num? b, num n, String Function(num) format) {
    final change = b == null || b == 0 || n == b ? '' : _percent((n - b) / b);
    final was = before == null ? '' : (b == null ? '-' : format(b)).padLeft(10);
    out.writeln('${label.padRight(28)}$was${format(n).padLeft(10)}  $change'.trimRight());
  }

  out.writeln('${name.padRight(28)}${before == null ? '' : 'before'.padLeft(10)}${'now'.padLeft(10)}');
  row('widget builds', before?.total, now.total, _count);
  int delta(String w) => ((now.builds[w] ?? 0) - (before?.builds[w] ?? 0)).abs();
  final widgets = {...now.builds.keys, ...?before?.builds.keys}.where((w) => before == null || delta(w) > 0).toList()
    ..sort((a, b) => before == null ? now.builds[b]!.compareTo(now.builds[a]!) : delta(b).compareTo(delta(a)));
  for (final w in widgets.take(5)) {
    row('  $w', before == null ? null : before.builds[w] ?? 0, now.builds[w] ?? 0, _count);
  }

  final frames = now.frames;
  if (frames != null) {
    final was = before?.frames;
    row('frames', was?['count'], frames['count']!, _count);
    row('  avg build', was?['buildMs'], frames['buildMs']!, _ms);
    row('  avg raster', was?['rasterMs'], frames['rasterMs']!, _ms);
    row('  slow frames', was?['slow'], frames['slow']!, _count);
  }
  return out.toString();
}

String _count(num n) => n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String _ms(num n) => '${n.toStringAsFixed(1)} ms';

String _percent(num ratio) => '${ratio > 0 ? '+' : ''}${(ratio * 100).round()}%';
