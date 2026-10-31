import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'engine.dart';

class Project {
  final listItems = <Element>{};

  Project(List<ResolvedUnitResult> units) {
    final collector = _Uses();
    for (final unit in units) {
      unit.unit.accept(collector);
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

const listWidgets = {'ListView', 'GridView', 'SliverList', 'SliverGrid', 'SliverChildBuilderDelegate'};

bool inListItem(AstNode node, [Project? project]) {
  for (var n = node.parent; n != null; n = n.parent) {
    if (_isCallback(n)) return false;
    final type = n is InstanceCreationExpression ? n.constructorName.type.element : null;
    if (listWidgets.any((c) => isFlutterClass(type, c))) return true;
    if (project != null && project.listItems.contains(_declared(n))) return true;
  }
  return false;
}

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
