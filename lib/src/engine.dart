import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

import 'rules/mediaquery_of.dart';

final allRules = <Rule>[MediaQueryOf()];

abstract class Rule {
  String get name;

  /// How much this costs at runtime: `high` or `medium`.
  String get impact;

  List<Finding> check(ResolvedUnitResult unit);
}

/// Replace [length] characters at [offset] with [replacement].
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

  /// Safe rewrites. Empty means "suggest": the message shows the fix, a human applies it.
  final List<Edit> edits;

  Finding(this.rule, ResolvedUnitResult unit, int offset, this.message, [this.edits = const []])
    : path = unit.path,
      line = unit.lineInfo.getLocation(offset).lineNumber,
      column = unit.lineInfo.getLocation(offset).columnNumber;

  bool get autoFix => edits.isNotEmpty;
}

class Report {
  final findings = <Finding>[];

  /// Files with imports the analyzer could not find (usually `flutter pub get` was not run).
  /// Rules skip code they can't resolve, so findings in these files may be missing.
  final unresolved = <String>[];
}

/// Runs [rules] on every Dart file under [path] (a file or a folder).
Future<Report> analyze(String path, [List<Rule>? rules]) async {
  final report = Report();
  final collection = AnalysisContextCollection(includedPaths: [p.normalize(p.absolute(path))]);
  for (final context in collection.contexts) {
    for (final file in context.contextRoot.analyzedFiles()) {
      if (!file.endsWith('.dart')) continue;
      final unit = await context.currentSession.getResolvedUnit(file);
      if (unit is! ResolvedUnitResult) continue;
      if (unit.diagnostics.any((d) => d.diagnosticCode.lowerCaseName == 'uri_does_not_exist')) {
        report.unresolved.add(file);
      }
      for (final rule in rules ?? allRules) {
        report.findings.addAll(rule.check(unit));
      }
    }
  }
  await collection.dispose();
  return report;
}

/// True when [e] is the Flutter class [name] (not a user class with the same name).
bool isFlutterClass(Element? e, String name) =>
    e is InterfaceElement && e.name == name && e.library.uri.toString().startsWith('package:flutter/');

/// Applies [edits] to [source]. An edit that overlaps an earlier one is skipped; the next run picks it up.
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

/// Before/after lines for every changed spot, like a small unified diff.
String diff(String source, List<Edit> edits) {
  final sorted = [...edits]..sort((a, b) => a.offset - b.offset);
  final out = StringBuffer();
  var i = 0;
  while (i < sorted.length) {
    final start = sorted[i].offset == 0 ? 0 : source.lastIndexOf('\n', sorted[i].offset - 1) + 1;
    var end = _lineEnd(source, sorted[i].offset + sorted[i].length);
    final hunk = <Edit>[];
    // Edits that start on a line already in this hunk join it.
    while (i < sorted.length && sorted[i].offset <= end) {
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

int _lineEnd(String s, int from) {
  final i = s.indexOf('\n', from);
  return i == -1 ? s.length : i;
}
