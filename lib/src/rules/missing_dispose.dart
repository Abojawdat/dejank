import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../engine.dart';
import '../heat.dart';
import '../project.dart';

class MissingDispose extends Rule {
  @override
  final name = 'missing-dispose';
  @override
  final impact = 'medium';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    for (final cls in unit.unit.declarations.whereType<ClassDeclaration>()) {
      final element = cls.declaredFragment?.element;
      final body = cls.body;
      if (element == null || body is! BlockClassBody || !isA(element.thisType, 'State')) continue;
      findings.addAll(_check(unit, cls, body));
    }
    return findings;
  }

  List<Finding> _check(ResolvedUnitResult unit, ClassDeclaration cls, BlockClassBody body) {
    final uses = _Uses();
    cls.accept(uses);
    final dispose = body.members
        .whereType<MethodDeclaration>()
        .where((m) => m.name.lexeme == 'dispose' && !m.isStatic)
        .firstOrNull;
    final inDispose = _Uses();
    dispose?.accept(inDispose);
    final superCall = dispose?.body is BlockFunctionBody
        ? (dispose!.body as BlockFunctionBody).block.statements
              .whereType<ExpressionStatement>()
              .where(
                (s) => switch (s.expression) {
                  MethodInvocation(target: SuperExpression(), :final methodName) => methodName.name == 'dispose',
                  _ => false,
                },
              )
              .firstOrNull
        : null;

    final missing = <(VariableDeclaration, String, bool)>[];
    for (final field in body.members.whereType<FieldDeclaration>().where((f) => !f.isStatic)) {
      for (final v in field.fields.variables) {
        final e = v.declaredFragment?.element.baseElement;
        if (e is! FieldElement) continue;
        final kind = _kind(e.type);
        if (kind == null) continue;
        final created = [if (v.initializer case final Expression init) init, ...?uses.assigned[e]];
        if (created.isEmpty || !created.every(_creates)) continue;
        if (uses.released.contains(e) || inDispose.read.contains(e)) continue;
        final nullable = e.type.nullabilitySuffix == NullabilitySuffix.question;
        final safe = nullable || v.initializer != null || uses.setInInitState.contains(e);
        missing.add((v, '${v.name.lexeme}${nullable ? '?' : ''}.$kind()', safe));
      }
    }
    if (missing.isEmpty) return const [];

    final allSafe = missing.every((m) => m.$3);
    final lines = [for (final (_, call, _) in missing) '$call;'];
    List<Edit> edits = const [];
    if (allSafe && dispose == null) {
      edits = [
        Edit(
          body.rightBracket.offset,
          0,
          '\n  @override\n  void dispose() {\n${lines.map((l) => '    $l\n').join()}    super.dispose();\n  }\n',
        ),
      ];
    } else if (allSafe && superCall != null) {
      final indent = ' ' * (unit.lineInfo.getLocation(superCall.offset).columnNumber - 1);
      edits = [Edit(superCall.offset, 0, lines.map((l) => '$l\n$indent').join())];
    }

    final first = missing.first.$1;
    return [
      Finding(
        this,
        unit,
        first.offset,
        [
          '${missing.length == 1 ? 'This ${_typeName(first)} is' : '${missing.length} objects this State creates are'} '
              'never ${_verb(lines)}: ${missing.map((m) => m.$1.name.lexeme).join(', ')}.',
          '${missing.length == 1 ? 'It keeps' : 'They keep'} running or holding memory (and listeners) after the '
              'screen is gone. In dispose():',
          ...lines.map((l) => '  $l'),
          if (!allSafe) 'Check each one is always set before dispose runs (a late field that was never set throws).',
        ].join('\n'),
        edits: edits,
        impact: missing.any((m) => m.$2.contains('cancel') || _typeName(m.$1) == 'AnimationController') ? 'high' : null,
      ),
    ];
  }

  static String _verb(List<String> lines) {
    final cancel = lines.where((l) => l.contains('.cancel()')).length;
    return cancel == 0
        ? 'disposed'
        : cancel == lines.length
        ? 'cancelled'
        : 'disposed or cancelled';
  }

  static String _typeName(VariableDeclaration v) => v.declaredFragment?.element.type.element?.name ?? 'object';

  static bool _creates(Expression e) => switch (e) {
    InstanceCreationExpression() => true,
    MethodInvocation(:final methodName) => methodName.name == 'listen',
    CascadeExpression(:final target) => _creates(target),
    _ => false,
  };

  static String? _kind(DartType type) {
    final e = type.element;
    final uri = e?.library?.uri.toString();
    if (uri == 'dart:async' && (e?.name == 'StreamSubscription' || e?.name == 'Timer')) return 'cancel';
    const disposable = [
      'AnimationController',
      'TextEditingController',
      'ScrollController',
      'PageController',
      'TabController',
      'FocusNode',
      'ValueNotifier',
    ];
    return disposable.any((c) => isA(type, c)) ? 'dispose' : null;
  }
}

class _Uses extends RecursiveAstVisitor<void> {
  final assigned = <FieldElement, List<Expression>>{};
  final released = <FieldElement>{};
  final read = <FieldElement>{};
  final setInInitState = <FieldElement>{};

  static FieldElement? _field(Expression? e) {
    final element = switch (e) {
      SimpleIdentifier(:final element) => element,
      PropertyAccess(target: ThisExpression(), :final propertyName) => propertyName.element,
      PrefixedIdentifier(:final identifier) => identifier.element,
      _ => null,
    };
    final variable = (element is PropertyAccessorElement ? element.variable : element)?.baseElement;
    return variable is FieldElement ? variable : null;
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    super.visitAssignmentExpression(node);
    final field = switch (node.writeElement) {
      PropertyAccessorElement(:final variable) when variable.baseElement is FieldElement =>
        variable.baseElement as FieldElement,
      _ => null,
    };
    if (field == null) return;
    assigned.putIfAbsent(field, () => []).add(node.rightHandSide);
    final statement = node.parent;
    final method = statement?.parent?.parent?.parent;
    if (statement is ExpressionStatement && method is MethodDeclaration && method.name.lexeme == 'initState') {
      setInInitState.add(field);
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    final name = node.methodName.name;
    if (name != 'dispose' && name != 'cancel') return;
    final field = _field(node.realTarget);
    if (field != null) released.add(field);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final field = _field(node);
    if (field != null) read.add(field);
  }
}
