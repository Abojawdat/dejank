import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'engine.dart';
import 'heat.dart';

class Project {
  final listItems = <Element>{};
  final fixedLists = <Element, int>{};
  final HeatMap heat;

  Project(List<ResolvedUnitResult> units) : heat = HeatMap(units) {
    final collector = _Uses();
    final fixed = _FixedLists(fixedLists);
    for (final unit in units) {
      unit.unit
        ..accept(collector)
        ..accept(fixed);
    }
    final todo = [...collector.roots];
    while (todo.isNotEmpty) {
      final e = todo.removeLast();
      if (!listItems.add(e)) continue;
      todo
        ..addAll(collector.uses[e] ?? const {})
        ..addAll(collector.members[e] ?? const []);
    }
  }
}

const listWidgets = {
  'ListView',
  'GridView',
  'SliverList',
  'SliverGrid',
  'SliverChildBuilderDelegate',
  'PageView',
  'AnimatedList',
  'SliverAnimatedList',
  'AnimatedGrid',
  'SliverAnimatedGrid',
  'ReorderableListView',
  'SliverReorderableList',
};

const _builderArgs = {'itemBuilder', 'separatorBuilder', 'builder', _positional};
const _positional = '';

bool inListItem(AstNode node, [Project? project]) {
  var repeated = false;
  String? via;
  for (AstNode? from = node, n = node.parent; n != null; from = n, n = n.parent) {
    if (_isCallback(n)) return false;
    switch (n) {
      case ForElement():
        repeated = true;
      case NamedArgument(:final name):
        via = name.lexeme;
      case ArgumentList(:final parent) when from is! NamedArgument:
        via = _positional;
        if (from is FunctionExpression && _repeats(parent)) repeated = true;
    }
    final type = n is InstanceCreationExpression ? n.constructorName.type.element : null;
    if (listWidgets.any((c) => isFlutterClass(type, c))) return repeated || _builderArgs.contains(via);
    if (via == 'itemBuilder' &&
        type is InterfaceElement &&
        !type.library.uri.toString().startsWith('package:flutter/')) {
      return true;
    }
    if (project != null && project.listItems.contains(_declared(n))) return true;
  }
  return false;
}

bool _repeats(AstNode? call) => switch (call) {
  MethodInvocation(:final methodName) => const {'map', 'expand', 'generate'}.contains(methodName.name),
  InstanceCreationExpression(:final constructorName) => constructorName.name?.name == 'generate',
  _ => false,
};

bool _isCallback(AstNode n) => n is NamedArgument && RegExp(r'^on[A-Z]').hasMatch(n.name.lexeme);

Element? _declared(AstNode n) => switch (n) {
  ClassDeclaration() => n.declaredFragment?.element,
  MethodDeclaration() => n.declaredFragment?.element,
  FunctionDeclaration(parent: CompilationUnit()) => n.declaredFragment?.element,
  _ => null,
}?.baseElement;

class _Uses extends RecursiveAstVisitor<void> {
  final uses = <Element, Set<Element>>{};
  final members = <Element, List<Element>>{};

  final roots = <Element>{};

  final _current = <Element>[];

  void _inside(AstNode node, void Function() visit) {
    final e = _declared(node);
    if (e == null) return visit();
    if (node is MethodDeclaration && _current.isNotEmpty && _entry(node)) {
      members.putIfAbsent(_current.last, () => []).add(e);
    }
    _current.add(e);
    visit();
    _current.removeLast();
  }

  static bool _entry(MethodDeclaration m) =>
      m.name.lexeme == 'build' || m.metadata.any((a) => a.name.name == 'override');

  void _use(AstNode node, Element? used) {
    if (used == null || _current.isEmpty) return;
    for (var n = node.parent; n != null && n is! ClassMember; n = n.parent) {
      if (_isCallback(n)) return;
    }
    used = used.baseElement;
    uses.putIfAbsent(_current.last, () => {}).add(used);
    if (inListItem(node)) roots.add(used);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) => _inside(node, () => super.visitClassDeclaration(node));

  @override
  void visitMethodDeclaration(MethodDeclaration node) => _inside(node, () => super.visitMethodDeclaration(node));

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) => _inside(node, () => super.visitFunctionDeclaration(node));

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _use(node, node.constructorName.type.element);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final e = node.element;
    if (e is MethodElement || e is TopLevelFunctionElement || e is GetterElement) _use(node, e);
  }
}

class _FixedLists extends RecursiveAstVisitor<void> {
  final Map<Element, int> into;
  _FixedLists(this.into);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    super.visitVariableDeclaration(node);
    final elements = switch (node.initializer) {
      ListLiteral(:final elements) || SetOrMapLiteral(:final elements) => elements,
      _ => null,
    };
    final e = node.declaredFragment?.element;
    final list = node.parent;
    if (elements == null || e == null || list is! VariableDeclarationList || !(list.isFinal || list.isConst)) return;
    if (elements.any((x) => x is ForElement || x is SpreadElement)) return;
    into[e.baseElement] = elements.length;
  }
}
