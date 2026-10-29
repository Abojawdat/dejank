import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dejank/src/engine.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('dejank', 'Finds slow Flutter code, fixes it, and proves it.')
    ..addCommand(ScanCommand())
    ..addCommand(FixCommand());
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
