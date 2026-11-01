import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../engine.dart';
import '../heat.dart';
import '../project.dart';

class BlocSelect extends Rule {
  @override
  final name = 'bloc-select';
  @override
  final impact = 'medium';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, findings));
    return findings;
  }
}

bool _from(Element? e, String package) => e?.library?.uri.toString().startsWith('package:$package/') ?? false;

bool _simple(DartType? t) {
  if (t == null) return false;
  if (t.element is EnumElement) return true;
  if (t.isDartCoreInt || t.isDartCoreDouble || t.isDartCoreNum || t.isDartCoreString || t.isDartCoreBool) return true;
  return t.element?.library?.uri.toString() == 'dart:core' && const {'DateTime', 'Duration'}.contains(t.element?.name);
}

class _Visitor extends RecursiveAstVisitor<void> {
  final Rule rule;
  final ResolvedUnitResult unit;
  final List<Finding> findings;
  _Visitor(this.rule, this.unit, this.findings);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    final type = node.constructorName.type;
    if (type.element?.name != 'BlocBuilder' || !_from(type.element, 'flutter_bloc')) return;
    final args = {
      for (final a in node.argumentList.arguments)
        if (a is NamedArgument) a.name.lexeme: a,
    };
    final builderArg = args['builder'];
    final builder = builderArg?.argumentExpression;
    if (args.containsKey('buildWhen') || builder is! FunctionExpression) return;
    final params = builder.parameters?.parameters ?? const <FormalParameter>[];
    final state = params.length == 2 ? params[1].declaredFragment?.element : null;
    if (state == null) return;
    final uses = <SimpleIdentifier>[];
    builder.body.accept(_References(state, uses));
    final fields = <String, DartType?>{};
    for (final use in uses) {
      final parent = use.parent;
      if (parent is! PrefixedIdentifier || parent.prefix != use || parent.parent is MethodInvocation) return;
      final getter = parent.identifier.element;
      if (getter is! PropertyAccessorElement) return;
      fields[parent.identifier.name] = parent.staticType;
    }
    final widgets = _widgets(builder.body);
    if (fields.isEmpty || fields.length > 3 || widgets < 3) return;
    final generic = node.staticType;
    final typeArgs = generic is InterfaceType ? generic.typeArguments.map((t) => t.getDisplayString()).toList() : null;
    if (typeArgs == null || typeArgs.length != 2) return;
    final bloc = (generic as InterfaceType).typeArguments.first.element;
    final sideReads = _SideReads(bloc);
    builder.body.accept(sideReads);
    final simple = fields.values.every(_simple) && !sideReads.found;
    final names = fields.keys.toList();
    final edits = <Edit>[];
    final indent = ' ' * (unit.lineInfo.getLocation(builderArg!.offset).columnNumber - 1);
    if (fields.length == 1 && simple) {
      final field = names.single;
      final name = _free(builder, field);
      final fieldType = fields.values.single!.getDisplayString();
      edits
        ..add(Edit(type.offset, type.length, 'BlocSelector<${typeArgs[0]}, ${typeArgs[1]}, $fieldType>'))
        ..add(Edit(builderArg.offset, 0, 'selector: (state) => state.$field,\n$indent'))
        ..add(Edit(params[1].offset, params[1].length, name));
      for (final use in uses) {
        final access = use.parent!;
        final interpolation = access.parent;
        final next = interpolation is InterpolationExpression && interpolation.rightBracket != null
            ? unit.content[interpolation.end]
            : '';
        if (interpolation is InterpolationExpression && !RegExp(r'[\w$]').hasMatch(next)) {
          edits.add(Edit(interpolation.offset, interpolation.length, '\$$name'));
        } else {
          edits.add(Edit(access.offset, access.length, name));
        }
      }
    } else if (simple) {
      final test = names.map((f) => 'previous.$f != current.$f').join(' || ');
      edits.add(Edit(builderArg.offset, 0, 'buildWhen: (previous, current) => $test,\n$indent'));
    }
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        [
          'This BlocBuilder rebuilds its $widgets widgets on every state change, but it only reads '
              '${names.map((n) => 'state.$n').join(', ')}.',
          fields.length == 1
              ? 'Use BlocSelector<${typeArgs[0]}, ${typeArgs[1]}, ...>(selector: (state) => state.${names.single}, '
                    'builder: ...): it rebuilds only when that value changes.'
              : 'Add buildWhen: (previous, current) => ${names.map((f) => 'previous.$f != current.$f').join(' || ')}.',
          if (sideReads.found)
            'The builder also reads the bloc another way (the cubit itself, or context.read / watch): check that '
                'value only changes together with ${names.length == 1 ? 'this field' : 'these fields'}.'
          else if (!simple)
            'Check that ${names.length == 1 ? 'this value gets' : 'these values get'} a new object when they change '
                '(a list changed in place would look the same and the screen would not update).',
        ].join('\n'),
        edits: edits,
        impact: widgets >= 15 ? 'high' : null,
      ),
    );
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    final method = node.methodName.element;
    if (node.methodName.name != 'watch' || method is! MethodElement) return;
    if (!_from(method, 'provider') && !_from(method, 'flutter_bloc')) return;
    final typeArgs = node.typeArguments?.arguments;
    if (typeArgs == null || typeArgs.length != 1) return;
    Expression chain = node;
    final names = <String>[];
    for (
      var parent = chain.parent;
      parent is PropertyAccess && parent.target == chain && !parent.isNullAware;
      parent = chain.parent
    ) {
      names.add(parent.propertyName.name);
      chain = parent;
    }
    if (names.isEmpty || (names.length == 1 && names.single == 'state') || chain.parent is MethodInvocation) return;
    final receiver = node.target;
    if (receiver == null) return;
    final target = unit.content.substring(receiver.offset, receiver.end);
    final watched = typeArgs.single.toSource();
    final select = '$target.select(($watched it) => it.${names.join('.')})';
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        [
          '$target.watch<$watched>() rebuilds on every change of $watched, but only .${names.join('.')} is read.',
          'Use $select: it rebuilds only when that value changes.',
          if (!_simple(chain.staticType))
            'Check that this value gets a new object when it changes (a list changed in place would look the same).',
        ].join('\n'),
        edits: _simple(chain.staticType) ? [Edit(node.offset, chain.end - node.offset, select)] : const [],
      ),
    );
  }

  static String _free(FunctionExpression builder, String wanted) {
    final taken = <String>{};
    builder.body.accept(_Names(taken));
    return taken.contains(wanted) ? 'value' : wanted;
  }

  static int _widgets(AstNode node) {
    var n = 0;
    node.accept(_Widgets(() => n++));
    return n;
  }
}

class _References extends RecursiveAstVisitor<void> {
  final Element variable;
  final List<SimpleIdentifier> into;
  _References(this.variable, this.into);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == variable) into.add(node);
  }
}

class _Names extends RecursiveAstVisitor<void> {
  final Set<String> into;
  _Names(this.into);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.parent is! PrefixedIdentifier || (node.parent as PrefixedIdentifier).prefix == node) into.add(node.name);
  }
}

class _Widgets extends RecursiveAstVisitor<void> {
  final void Function() found;
  _Widgets(this.found);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (!node.isConst && isA(node.staticType, 'Widget')) found();
    super.visitInstanceCreationExpression(node);
  }
}

class _SideReads extends RecursiveAstVisitor<void> {
  final Element? bloc;
  var found = false;
  _SideReads(this.bloc);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (bloc != null && node.staticType?.element == bloc) found = true;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (const {'read', 'watch', 'select'}.contains(node.methodName.name)) found = true;
    super.visitMethodInvocation(node);
  }
}
