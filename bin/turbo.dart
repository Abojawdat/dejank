import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:args/command_runner.dart';
import 'package:flutter_turbo/src/engine.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('turbo', 'Finds slow Flutter code, fixes it, and proves it.')
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
  final description = 'List slow code with file:line, impact, and whether `turbo fix` can fix it.';
  @override
  String get invocation => 'turbo scan [path]';

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
          : '\n${report.findings.length} problems: $auto auto-fixable (run `turbo fix`), $suggest need a human.',
    );
  }
}

class FixCommand extends Command<void> {
  @override
  final name = 'fix';
  @override
  final description = 'Apply the safe fixes and show what changed.';
  @override
  String get invocation => 'turbo fix [path]';

  @override
  Future<void> run() async {
    final report = await _analyze(argResults!.rest);
    final byFile = <String, List<Finding>>{};
    for (final f in report.findings.where((f) => f.autoFix)) {
      byFile.putIfAbsent(f.path, () => []).add(f);
    }
    var fixed = 0, files = 0;
    for (final MapEntry(key: path, value: findings) in byFile.entries) {
      final edits = [for (final f in findings) ...f.edits];
      final file = File(path);
      final before = file.readAsStringSync();
      final after = applyEdits(before, edits);
      if (_hasSyntaxErrors(after) && !_hasSyntaxErrors(before)) {
        stderr.writeln('Skipped ${p.relative(path)}: the fix would break it. This is a turbo bug, please report it.');
        continue;
      }
      file.writeAsStringSync(after);
      fixed += findings.length;
      files++;
      print('${p.relative(path)}\n${diff(before, edits)}');
    }
    final suggest = report.findings.where((f) => !f.autoFix).length;
    print(
      'Fixed $fixed problems in $files files.'
      '${suggest > 0 ? ' $suggest need a human, see `turbo scan`.' : ''}',
    );
  }
}

Future<Report> _analyze(List<String> rest) async {
  final path = rest.isEmpty ? '.' : rest.first;
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    throw UsageException('Not found: $path', 'turbo scan [path]');
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

bool _hasSyntaxErrors(String source) => parseString(content: source, throwIfDiagnostics: false).errors.isNotEmpty;
