import 'dart:io';

import 'package:flutter_turbo/src/engine.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    if (!File('test/fixtures/.dart_tool/package_config.json').existsSync()) {
      final r = await Process.run('flutter', ['pub', 'get'], workingDirectory: 'test/fixtures');
      if (r.exitCode != 0) fail('flutter pub get failed in test/fixtures:\n${r.stderr}');
    }
  });

  test('fixtures compile against real Flutter', () async {
    final r = await Process.run('dart', ['analyze', '--no-fatal-warnings', 'test/fixtures']);
    expect(r.exitCode, 0, reason: '${r.stdout}');
  });

  for (final rule in allRules) {
    test(rule.name, () async {
      final dir = 'test/fixtures/lib/${rule.name.replaceAll('-', '_')}';
      final input = File('$dir/input.dart').readAsStringSync();
      final report = await analyze('$dir/input.dart', [rule]);
      expect(report.unresolved, isEmpty);

      final lintLines = {
        for (final (i, line) in input.split('\n').indexed)
          if (line.contains('// LINT')) i + 1,
      };
      expect(report.findings.map((f) => f.line).toSet(), lintLines, reason: 'flagged lines');

      final expected = File('$dir/expected.dart');
      final fixed = applyEdits(input, [for (final f in report.findings) ...f.edits]);
      expect(fixed, expected.existsSync() ? expected.readAsStringSync() : input);

      if (expected.existsSync()) {
        final again = await analyze(expected.path, [rule]);
        expect(again.findings.where((f) => f.autoFix), isEmpty, reason: 'expected.dart still has fixes');
      }
    });
  }

  test('diff shows before/after lines', () {
    const source = 'a\nfinal x = MediaQuery.of(context).size;\nb';
    expect(
      diff(source, [const Edit(23, 16, 'sizeOf(context)')]),
      '  @@ line 2\n'
      '  - final x = MediaQuery.of(context).size;\n'
      '  + final x = MediaQuery.sizeOf(context);\n',
    );
  });
}
