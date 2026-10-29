import 'dart:async';
import 'dart:convert';

import 'package:dejank_meter/dejank_meter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => CounterState();
}

class CounterState extends State<Counter> {
  var count = 0;

  void bump() => setState(() => count++);

  @override
  Widget build(BuildContext context) => Text('$count', textDirection: TextDirection.ltr);
}

void main() {
  testWidgets('counts builds per widget and restores the hook', (tester) async {
    final lines = <String>[];
    await runZoned(
      () => measure('counter', () async {
        await tester.pumpWidget(const Counter());
        for (var i = 0; i < 3; i++) {
          tester.state<CounterState>(find.byType(Counter)).bump();
          await tester.pump();
        }
      }),
      zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)),
    );

    final records = [
      for (final l in lines)
        if (l.startsWith(marker)) jsonDecode(l.substring(marker.length)) as Map<String, dynamic>,
    ];
    final counter = records.singleWhere((r) => r['widget'] == 'Counter');
    expect(counter, {'name': 'counter', 'widget': 'Counter', 'builds': 4});
    expect(debugOnRebuildDirtyWidget, isNull);
  });
}
