import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/file_system/overlay_file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:path/path.dart' as p;

import 'project.dart';
import 'rules/bloc_select.dart';
import 'rules/builder_child.dart';
import 'rules/controller_in_build.dart';
import 'rules/eager_list.dart';
import 'rules/future_in_build.dart';
import 'rules/hot_allocation.dart';
import 'rules/image_cache_size.dart';
import 'rules/intrinsic_in_list.dart';
import 'rules/mediaquery_of.dart';
import 'rules/missing_dispose.dart';
import 'rules/opacity_animation.dart';
import 'rules/serial_awaits_main.dart';
import 'rules/shrinkwrap_in_column.dart';

final allRules = <Rule>[
  MediaQueryOf(),
  OpacityAnimation(),
  ImageCacheSize(),
  ShrinkWrapInColumn(),
  IntrinsicInList(),
  SerialAwaitsMain(),
  FutureInBuild(),
  ControllerInBuild(),
  HotAllocation(),
  MissingDispose(),
  BuilderChild(),
  EagerList(),
  BlocSelect(),
];

abstract class Rule {
  String get name;

  String get impact;

  List<Finding> check(ResolvedUnitResult unit, Project project);
}

class Edit {
  final int offset, length;
  final String replacement;
  const Edit(this.offset, this.length, this.replacement);
}

class Finding {
  final Rule rule;
  final String path;
  final int line, column;
  final String message;
  final String impact;

  final List<Edit> edits;

  Finding(this.rule, ResolvedUnitResult unit, int offset, this.message, {this.edits = const [], String? impact})
    : impact = impact ?? rule.impact,
      path = unit.path,
      line = unit.lineInfo.getLocation(offset).lineNumber,
      column = unit.lineInfo.getLocation(offset).columnNumber;

  bool get autoFix => edits.isNotEmpty;
}

List<Finding> applicable(List<Finding> findings) {
  final taken = <Edit>[];
  final out = <Finding>[];
  for (final f in [...findings]..sort((a, b) => a.edits.first.offset - b.edits.first.offset)) {
    if (f.edits.any((e) => taken.any((t) => e.offset < t.offset + t.length && t.offset < e.offset + e.length))) {
      continue;
    }
    taken.addAll(f.edits);
    out.add(f);
  }
  return out;
}

final _ignore = RegExp(r'//\s*dejank:ignore\b(.*)');

bool _ignored(List<String> lines, Finding f) {
  for (final (i, sameLine) in [(f.line - 1, true), (f.line - 2, false)]) {
    if (i < 0 || (!sameLine && !lines[i].trimLeft().startsWith('//'))) continue;
    final m = _ignore.firstMatch(lines[i]);
    if (m == null) continue;
    final names = m[1]!.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty);
    if (names.isEmpty || names.contains(f.rule.name)) return true;
  }
  return false;
}

class Report {
  final findings = <Finding>[];

  final unresolved = <String>[];

  final errors = <String, int>{};
}

Future<Report> analyze(String path, [List<Rule>? rules]) async {
  final report = Report();
  final collection = AnalysisContextCollection(includedPaths: [p.normalize(p.absolute(path))]);
  final units = <ResolvedUnitResult>[];
  for (final context in collection.contexts) {
    for (final file in context.contextRoot.analyzedFiles()) {
      if (!file.endsWith('.dart')) continue;
      final unit = await context.currentSession.getResolvedUnit(file);
      if (unit is! ResolvedUnitResult) continue;
      if (unit.diagnostics.any((d) => d.diagnosticCode.lowerCaseName == 'uri_does_not_exist')) {
        report.unresolved.add(file);
      }
      report.errors[file] = _errorCount(unit);
      units.add(unit);
    }
  }
  final project = Project(units);
  for (final unit in units) {
    final lines = unit.content.split('\n');
    for (final rule in rules ?? allRules) {
      report.findings.addAll(rule.check(unit, project).where((f) => !_ignored(lines, f)));
    }
  }
  await collection.dispose();
  report.findings.sort((a, b) => a.path == b.path ? a.line - b.line : a.path.compareTo(b.path));
  return report;
}

Future<Set<String>> wouldBreak(Report report, Map<String, String> changes) async {
  final overlay = OverlayResourceProvider(PhysicalResourceProvider.INSTANCE);
  for (final MapEntry(key: path, value: content) in changes.entries) {
    overlay.setOverlay(path, content: content, modificationStamp: 0);
  }
  final broken = <String>{};
  final collection = AnalysisContextCollection(includedPaths: changes.keys.toList(), resourceProvider: overlay);
  for (final path in changes.keys) {
    final unit = await collection.contextFor(path).currentSession.getResolvedUnit(path);
    if (unit is! ResolvedUnitResult || _errorCount(unit) > (report.errors[path] ?? 0)) broken.add(path);
  }
  await collection.dispose();
  return broken;
}

int _errorCount(ResolvedUnitResult unit) => unit.diagnostics.where((d) => d.severity == Severity.error).length;

bool isFlutterClass(Element? e, String name) =>
    e is InterfaceElement && e.name == name && e.library.uri.toString().startsWith('package:flutter/');

String applyEdits(String source, List<Edit> edits) {
  final sorted = [...edits]..sort((a, b) => a.offset - b.offset);
  final out = StringBuffer();
  var pos = 0;
  for (final e in sorted) {
    if (e.offset < pos) continue;
    out
      ..write(source.substring(pos, e.offset))
      ..write(e.replacement);
    pos = e.offset + e.length;
  }
  return (out..write(source.substring(pos))).toString();
}

String diff(String source, List<Edit> edits) {
  final sorted = [...edits]..sort((a, b) => a.offset - b.offset);
  final out = StringBuffer();
  var i = 0;
  while (i < sorted.length) {
    final start = _lineStart(source, sorted[i].offset);
    var end = _lineEnd(source, sorted[i].offset + sorted[i].length);
    final hunk = <Edit>[];
    while (i < sorted.length && _lineStart(source, sorted[i].offset) <= end + 1) {
      final e = sorted[i++];
      hunk.add(Edit(e.offset - start, e.length, e.replacement));
      end = _lineEnd(source, e.offset + e.length);
    }
    final before = source.substring(start, end);
    out.writeln('  @@ line ${'\n'.allMatches(source.substring(0, start)).length + 1}');
    for (final l in before.split('\n')) {
      out.writeln('  - $l');
    }
    for (final l in applyEdits(before, hunk).split('\n')) {
      out.writeln('  + $l');
    }
  }
  return out.toString();
}

int _lineStart(String s, int offset) => offset == 0 ? 0 : s.lastIndexOf('\n', offset - 1) + 1;

int _lineEnd(String s, int from) {
  final i = s.indexOf('\n', from);
  return i == -1 ? s.length : i;
}
