import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../engine.dart';
import '../heat.dart';
import '../project.dart';

class EagerList extends Rule {
  @override
  final name = 'eager-list';
  @override
  final impact = 'medium';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, project, findings));
    return findings;
  }
}

const _small = 20;

class _Visitor extends RecursiveAstVisitor<void> {
  final Rule rule;
  final ResolvedUnitResult unit;
  final Project project;
  final List<Finding> findings;
  _Visitor(this.rule, this.unit, this.project, this.findings);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    final type = node.constructorName.type.element;
    final ctor = node.constructorName.name?.name;
    final list =
        (isFlutterClass(type, 'ListView') && ctor == null) ||
        (isFlutterClass(type, 'GridView') && (ctor == 'count' || ctor == 'extent'));
    final column = isFlutterClass(type, 'Column') || isFlutterClass(type, 'Wrap');
    if (!list && !column) return;
    final children = node.argumentList.arguments
        .whereType<NamedArgument>()
        .where((a) => a.name.lexeme == 'children')
        .firstOrNull
        ?.argumentExpression;
    if (children == null) return;
    final source = _dataSource(children);
    if (source == null) return;
    if (column && !_inScrollView(node)) return;
    final data = source.toSource();
    if (list) {
      final fix = isFlutterClass(type, 'ListView') ? _toBuilder(node, children) : const <Edit>[];
      findings.add(
        Finding(
          rule,
          unit,
          node.offset,
          [
            '${node.constructorName.toSource()}(children: ...) creates a widget for every item in $data up front.',
            'Use ${isFlutterClass(type, 'ListView') ? 'ListView.builder' : 'GridView.builder'}(itemCount: ..., '
                'itemBuilder: ...): it only builds the items on screen.',
          ].join('\n'),
          edits: fix,
        ),
      );
    } else {
      findings.add(
        Finding(
          rule,
          unit,
          node.offset,
          [
            'This ${type!.name} in a scroll view builds and lays out a widget for every item in $data, '
                'however long it gets.',
            'Use a lazy list instead: ListView.builder, or CustomScrollView with SliverList.builder for the items and '
                'SliverToBoxAdapter for the rest.',
          ].join('\n'),
          impact: 'high',
        ),
      );
    }
  }

  Expression? _dataSource(Expression children) {
    Expression? source;
    if (children case MethodInvocation(methodName: SimpleIdentifier(name: 'toList'), :final realTarget?)) {
      if (realTarget case MethodInvocation(methodName: SimpleIdentifier(name: 'map'), :final realTarget?)) {
        source = realTarget;
      }
    } else if (children is ListLiteral) {
      for (final e in children.elements) {
        if (e case ForElement(forLoopParts: ForEachParts(:final iterable))) source ??= iterable;
        if (e case SpreadElement(
          expression: MethodInvocation(methodName: SimpleIdentifier(name: 'map'), :final realTarget?),
        )) {
          source ??= realTarget;
        }
      }
    }
    if (source == null || _short(source)) return null;
    return source;
  }

  bool _short(Expression e) {
    switch (e) {
      case PropertyAccess(:final realTarget, :final propertyName)
          when const {'indexed', 'reversed', 'entries', 'keys', 'values'}.contains(propertyName.name):
        return _short(realTarget);
      case PrefixedIdentifier(:final prefix, :final identifier)
          when const {'indexed', 'reversed', 'entries', 'keys'}.contains(identifier.name):
        return _short(prefix);
      case MethodInvocation(:final realTarget?, :final methodName)
          when const {'toList', 'where', 'whereType', 'skip'}.contains(methodName.name):
        return _short(realTarget);
    }
    final type = e.staticType;
    if (type is InterfaceType && isA(type.typeArguments.firstOrNull, 'Widget')) return true;
    final element = switch (e) {
      SimpleIdentifier(:final element) => element,
      PrefixedIdentifier(:final identifier) => identifier.element,
      PropertyAccess(:final propertyName) => propertyName.element,
      _ => null,
    };
    final variable = (element is PropertyAccessorElement ? element.variable : element)?.baseElement;
    if ((project.fixedLists[variable] ?? _small + 1) <= _small) return true;
    int? count(ArgumentList args) => switch (args.arguments.firstOrNull) {
      IntegerLiteral(:final value) => value,
      _ => null,
    };
    return switch (e) {
      ListLiteral() || SetOrMapLiteral() => true,
      PrefixedIdentifier(identifier: SimpleIdentifier(name: 'values')) => true,
      MethodInvocation(methodName: SimpleIdentifier(name: 'take'), :final argumentList) =>
        (count(argumentList) ?? _small + 1) <= _small,
      InstanceCreationExpression(:final constructorName, :final argumentList)
          when constructorName.name?.name == 'generate' =>
        (count(argumentList) ?? _small + 1) <= _small,
      _ => false,
    };
  }

  static bool _inScrollView(AstNode node) {
    for (var n = node.parent; n != null; n = n.parent) {
      if (n is InstanceCreationExpression) {
        final t = n.constructorName.type.element;
        if (isFlutterClass(t, 'SingleChildScrollView') || isFlutterClass(t, 'SliverToBoxAdapter')) return true;
        if (!const {
          'Padding',
          'Center',
          'Align',
          'SafeArea',
          'Container',
          'DecoratedBox',
          'ColoredBox',
        }.any((c) => isFlutterClass(t, c))) {
          return false;
        }
      }
      if (n is FunctionBody || n is ClassMember) return false;
    }
    return false;
  }

  List<Edit> _toBuilder(InstanceCreationExpression node, Expression children) {
    final (items, param, item) = switch (children) {
      MethodInvocation(
        realTarget: MethodInvocation(
          :final realTarget?,
          argumentList: ArgumentList(
            arguments: [FunctionExpression(:final parameters?, body: ExpressionFunctionBody(:final expression))],
          ),
        ),
      )
          when parameters.parameters.length == 1 =>
        (realTarget, parameters.parameters.single.declaredFragment?.element, expression),
      ListLiteral(
        elements: [
          ForElement(forLoopParts: ForEachPartsWithDeclaration(:final loopVariable, :final iterable), :final body),
        ],
      )
          when body is Expression =>
        (iterable, loopVariable.declaredFragment?.element, body),
      _ => (null, null, null),
    };
    if (items == null || param == null || item == null) return const [];
    if (items is! SimpleIdentifier && items is! PrefixedIdentifier && items is! PropertyAccess) return const [];
    if (!(items.staticType?.element?.name == 'List')) return const [];
    final names = <String>{};
    item.accept(_Names(names));
    final index = names.contains('i') ? 'index' : 'i';
    if (names.contains(index)) return const [];
    final list = items.toSource();
    final uses = <SimpleIdentifier>[];
    item.accept(_Uses(param, uses));
    var text = unit.content.substring(item.offset, item.end);
    for (final u in uses.reversed) {
      text = text.replaceRange(u.offset - item.offset, u.end - item.offset, '$list[$index]');
    }
    final arg = children.parent as NamedArgument;
    return [
      Edit(node.constructorName.type.end, 0, '.builder'),
      Edit(arg.offset, arg.length, 'itemCount: $list.length, itemBuilder: (_, $index) => $text'),
    ];
  }
}

class _Names extends RecursiveAstVisitor<void> {
  final Set<String> into;
  _Names(this.into);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) => into.add(node.name);
}

class _Uses extends RecursiveAstVisitor<void> {
  final Element param;
  final List<SimpleIdentifier> into;
  _Uses(this.param, this.into);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == param) into.add(node);
  }
}
