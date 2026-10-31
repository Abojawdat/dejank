import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../engine.dart';
import '../heat.dart';
import '../project.dart';

class HotAllocation extends Rule {
  @override
  final name = 'hot-allocation';
  @override
  final impact = 'medium';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, project, findings));
    return findings;
  }
}

String? _costly(Element? e) {
  final uri = e?.library?.uri.toString() ?? '';
  return switch (e?.name) {
    'RegExp' when uri == 'dart:core' => 'RegExp',
    'DateFormat' || 'NumberFormat' when uri.startsWith('package:intl/') => e!.name,
    'TextPainter' when uri.startsWith('package:flutter/') => 'TextPainter',
    _ => null,
  };
}

class _Visitor extends RecursiveAstVisitor<void> {
  final Rule rule;
  final ResolvedUnitResult unit;
  final Project project;
  final List<Finding> findings;
  final _used = <ClassDeclaration, Set<String>>{};
  _Visitor(this.rule, this.unit, this.project, this.findings);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    final type = _costly(node.constructorName.type.element);
    if (type == null) return;
    final hot = project.heat.at(node);
    if (hot.heat.index < Heat.item.index) return;
    final why = switch (type) {
      'RegExp' => 'Compiling the pattern each time is wasted work. Create it once, as a static final field.',
      'TextPainter' =>
        'Laying out text in a new TextPainter each time is expensive. Keep one and call layout() '
            'only when the text changes.',
      _ =>
        'Parsing the pattern each time is wasted work. Create it once, as a field or a static final '
            '(if the app switches locale at runtime, keep one per locale).',
    };
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        'Creates a new $type ${hot.heat.when}: ${hot.path}.\n$why',
        edits: type == 'RegExp' ? _hoist(node) : const [],
        impact: hot.heat == Heat.frame ? 'high' : 'medium',
      ),
    );
  }

  List<Edit> _hoist(InstanceCreationExpression node) {
    bool plain(Expression e) =>
        e is SimpleStringLiteral ||
        e is BooleanLiteral ||
        (e is AdjacentStrings && e.strings.every((s) => s is SimpleStringLiteral));
    final constant = node.argumentList.arguments.every((a) => plain(a.argumentExpression));
    final cls = node.thisOrAncestorOfType<ClassDeclaration>();
    final body = cls?.body;
    if (!constant || cls == null || body is! BlockClassBody) return const [];
    final taken = _used.putIfAbsent(
      cls,
      () => {
        for (final m in body.members)
          if (m is FieldDeclaration)
            for (final v in m.fields.variables) v.name.lexeme
          else if (m is MethodDeclaration)
            m.name.lexeme,
      },
    );
    var name = '_regExp';
    for (var i = 2; taken.contains(name); i++) {
      name = '_regExp$i';
    }
    taken.add(name);
    final source = unit.content.substring(node.offset, node.end);
    return [Edit(body.leftBracket.end, 0, '\n  static final $name = $source;\n'), Edit(node.offset, node.length, name)];
  }
}
