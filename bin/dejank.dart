import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dejank/src/engine.dart';
import 'package:dejank/src/measure.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('dejank', 'Finds slow Flutter code, fixes it, and proves it.')
    ..addCommand(ScanCommand())
    ..addCommand(FixCommand())
    ..addCommand(MeasureCommand());
  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  }
}

class ScanCommand extends Command<void> {
  @override
  final name = 'scan';
  @override
  final description = 'List slow code with file:line, impact, and whether `dejank fix` can fix it.';
  @override
  String get invocation => 'dejank scan [path]';

  @override
  Future<void> run() async {
    final report = await _analyze(argResults!.rest);
    for (final f in report.findings) {
      print(
        '${p.relative(f.path)}:${f.line}:${f.column}  ${f.rule.name}  ${f.rule.impact}  '
        '${f.autoFix ? 'auto' : 'suggest'}',
      );
      print('  ${f.message.replaceAll('\n', '\n  ')}');
    }
    final auto = report.findings.where((f) => f.autoFix).length;
    final suggest = report.findings.length - auto;
    print(
      report.findings.isEmpty
          ? 'No problems found.'
          : '\n${report.findings.length} problems: $auto auto-fixable (run `dejank fix`), $suggest need a human.',
    );
  }
}

class FixCommand extends Command<void> {
  @override
  final name = 'fix';
  @override
  final description = 'Apply the safe fixes and show what changed.';
  @override
  String get invocation => 'dejank fix [path]';

  @override
  Future<void> run() async {
    final report = await _analyze(argResults!.rest);
    final byFile = <String, List<Finding>>{};
    for (final f in report.findings.where((f) => f.autoFix)) {
      byFile.putIfAbsent(f.path, () => []).add(f);
    }
    final before = {for (final path in byFile.keys) path: File(path).readAsStringSync()};
    final after = {
      for (final MapEntry(key: path, value: findings) in byFile.entries)
        path: applyEdits(before[path]!, [for (final f in findings) ...f.edits]),
    };
    final broken = await wouldBreak(report, after);
    var fixed = 0, files = 0;
    for (final MapEntry(key: path, value: findings) in byFile.entries) {
      if (broken.contains(path)) {
        stderr.writeln('Skipped ${p.relative(path)}: the fix would break it. This is a dejank bug, please report it.');
        continue;
      }
      File(path).writeAsStringSync(after[path]!);
      fixed += findings.length;
      files++;
      print('${p.relative(path)}\n${diff(before[path]!, [for (final f in findings) ...f.edits])}');
    }
    final suggest = report.findings.where((f) => !f.autoFix).length;
    print(
      'Fixed $fixed problems in $files files.'
      '${suggest > 0 ? ' $suggest need a human, see `dejank scan`.' : ''}',
    );
  }
}

class MeasureCommand extends Command<void> {
  @override
  final name = 'measure';
  @override
  final description = 'Run a test that uses dejank_meter, save its numbers, and compare them with the last run.';
  @override
  String get invocation => 'dejank measure <test file> [-d device]';

  MeasureCommand() {
    argParser.addOption('device', abbr: 'd', help: 'Run on this device. Frame times need a real device.');
  }

  @override
  Future<void> run() async {
    final test = argResults!.rest.firstOrNull ?? usageException('Which test file should run?');
    if (!File(test).existsSync()) usageException('Not found: $test');
    var root = File(test).absolute.parent;
    while (!File(p.join(root.path, 'pubspec.yaml')).existsSync()) {
      if (root.parent.path == root.path) usageException('No pubspec.yaml above $test');
      root = root.parent;
    }
    final device = argResults!.option('device');
    print('Running ${p.relative(test)}...');
    final result = await Process.run(
      'flutter',
      [
        'test',
        p.relative(File(test).absolute.path, from: root.path),
        if (device != null) ...['-d', device],
      ],
      workingDirectory: root.path,
      runInShell: Platform.isWindows,
    );
    if (result.exitCode != 0) {
      stderr
        ..writeln(result.stdout)
        ..writeln(result.stderr)
        ..writeln('The test failed, nothing was saved.');
      exitCode = 1;
      return;
    }
    final runs = parseRuns(LineSplitter.split('${result.stdout}'));
    if (runs.isEmpty) {
      stderr.writeln("No numbers found. Wrap the steps in measure('name', () async { ... }) from dejank_meter.");
      exitCode = 1;
      return;
    }
    final lib = Directory(p.join(root.path, 'lib'));
    final own = {
      if (lib.existsSync())
        for (final f in lib.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
          for (final m in RegExp(r'class\s+(\w+)').allMatches(f.readAsStringSync())) m[1]!,
    };
    var first = true;
    for (final MapEntry(key: name, value: now) in runs.entries) {
      final file = File(p.join(root.path, '.dejank', '${name.replaceAll(RegExp(r'[^\w-]'), '_')}.json'));
      final before = file.existsSync()
          ? Run.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)
          : null;
      if (before != null) first = false;
      print('\n${table(name, before, now, own: own)}');
      file
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(now.toJson()));
    }
    if (first) print('Saved in .dejank/. Change something (like `dejank fix`) and run again to compare.');
  }
}

Future<Report> _analyze(List<String> rest) async {
  final path = rest.isEmpty ? '.' : rest.first;
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    throw UsageException('Not found: $path', 'dejank scan [path]');
  }
  final report = await analyze(path);
  if (report.unresolved.isNotEmpty) {
    stderr.writeln(
      'Warning: ${report.unresolved.length} files have imports that could not be found. '
      'Run `flutter pub get` first, or some problems will be missed.',
    );
  }
  return report;
}
