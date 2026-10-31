import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../engine.dart';
import '../heat.dart';
import '../project.dart';

class BuilderChild extends Rule {
  @override
  final name = 'builder-child';
  @override
  final impact = 'high';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, findings));
    return findings;
  }
}

const _childParam = {
  'AnimatedBuilder': 1,
  'ListenableBuilder': 1,
  'ValueListenableBuilder': 2,
  'TweenAnimationBuilder': 2,
};

class _Visitor extends RecursiveAstVisitor<void> {
  final Rule rule;
  final ResolvedUnitResult unit;
  final List<Finding> findings;
  _Visitor(this.rule, this.unit, this.findings);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    final type = node.constructorName.type.element;
    final kind = _childParam.keys.where((k) => isFlutterClass(type, k)).firstOrNull;
    if (kind == null) return;
    final args = {
      for (final a in node.argumentList.arguments)
        if (a is NamedArgument) a.name.lexeme: a,
    };
    final builder = args['builder']?.argumentExpression;
    if (args.containsKey('child') || builder is! FunctionExpression) return;
    final params = builder.parameters?.parameters ?? const <FormalParameter>[];
    final index = _childParam[kind]!;
    if (params.length <= index) return;

    final inside = <Element>{};
    builder.accept(_Declared(inside));
    final body = builder.body;
    final root = switch (body) {
      ExpressionFunctionBody(:final expression) => expression,
      BlockFunctionBody(:final block) => block.statements.whereType<ReturnStatement>().lastOrNull?.expression,
      _ => null,
    };
    if (root == null) return;
    final moves = <InstanceCreationExpression>[];
    void collect(AstNode n) {
      if (n != root && n is InstanceCreationExpression && _worthMoving(n, inside)) {
        moves.add(n);
        return;
      }
      for (final child in n.childEntities.whereType<AstNode>()) {
        if (child is! FunctionExpression) collect(child);
      }
    }

    collect(root);
    if (moves.isEmpty) return;
    final move = moves.first;
    final widgets = _count(move);
    final what = '${move.constructorName.toSource()}(...)';
    final edits = moves.length == 1 ? _edits(node, builder, params[index], move) : const <Edit>[];
    findings.add(
      Finding(
        rule,
        unit,
        move.offset,
        [
          '$kind rebuilds $what ($widgets objects each time) '
              '${kind == 'ValueListenableBuilder' ? 'on every value change' : 'on every frame'}, but it never reads the '
              '${kind == 'ValueListenableBuilder' ? 'value' : 'animation'}.',
          'Pass it as child: to the $kind and use the builder\'s child parameter: it is then built once.',
        ].join('\n'),
        edits: edits,
        impact: kind == 'ValueListenableBuilder' || kind == 'ListenableBuilder' ? 'medium' : null,
      ),
    );
  }

  List<Edit> _edits(InstanceCreationExpression owner, FunctionExpression builder, FormalParameter param, AstNode move) {
    final name = param.name?.lexeme;
    final rename = name == null || name.startsWith('_');
    if (rename && _usesName(builder, 'child')) return const [];
    final childName = rename ? 'child' : name;
    final all = owner.argumentList.arguments;
    final last = all.last;
    final sep = unit.content.substring(all[all.length - 2].end, last.offset);
    final source = unit.content.substring(move.offset, move.end);
    return [
      if (rename) Edit(param.name?.offset ?? param.offset, param.name?.length ?? param.length, 'child'),
      Edit(move.offset, move.length, '$childName!'),
      Edit(last.end, 0, '${sep}child: $source'),
    ];
  }

  static bool _usesName(AstNode node, String name) {
    var found = false;
    node.accept(_Names((n) => found |= n == name));
    return found;
  }

  static int _count(AstNode node) {
    var n = 0;
    node.accept(_Creations(() => n++));
    return n;
  }

  static bool _worthMoving(InstanceCreationExpression node, Set<Element> inside) {
    if (node.isConst || !isA(node.staticType, 'Widget') || _count(node) < 2) return false;
    final check = _Independent(inside);
    node.accept(check);
    return check.ok;
  }
}

class _Declared extends RecursiveAstVisitor<void> {
  final Set<Element> into;
  _Declared(this.into);

  @override
  void visitFormalParameterList(FormalParameterList node) {
    for (final p in node.parameters) {
      if (p.declaredFragment?.element case final Element e) into.add(e);
    }
    super.visitFormalParameterList(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.declaredFragment?.element case final Element e) into.add(e);
    super.visitVariableDeclaration(node);
  }
}

class _Independent extends RecursiveAstVisitor<void> {
  final Set<Element> inside;
  var ok = true;
  _Independent(this.inside);

  bool _app(Element? e) {
    final uri = e?.library?.uri;
    return uri != null && !uri.isScheme('dart') && !uri.toString().startsWith('package:flutter/');
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final e = node.element;
    final type = node.staticType;
    if (inside.contains(e) || isA(type, 'Listenable') || node.name == 'value') {
      ok = false;
    } else if (e is PropertyAccessorElement && _app(e)) {
      final v = e.variable;
      if (!e.isOriginVariable || !(v.isFinal || v.isConst)) ok = false;
    } else if ((e is MethodElement || e is TopLevelFunctionElement) && _app(e)) {
      ok = false;
    }
  }
}

class _Creations extends RecursiveAstVisitor<void> {
  final void Function() found;
  _Creations(this.found);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!node.isConst) found();
    super.visitInstanceCreationExpression(node);
  }
}

class _Names extends RecursiveAstVisitor<void> {
  final void Function(String) found;
  _Names(this.found);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) => found(node.name);
}
