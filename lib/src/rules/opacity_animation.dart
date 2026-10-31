import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import '../engine.dart';
import '../project.dart';

class OpacityAnimation extends Rule {
  @override
  final name = 'opacity-animation';
  @override
  final impact = 'medium';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, findings));
    return findings;
  }
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
    if (node.constructorName.name != null || !isFlutterClass(type.element, 'AnimatedBuilder')) return;

    final all = node.argumentList.arguments;
    if (!all.every((a) => a is NamedArgument)) return;
    final args = {for (final a in all.cast<NamedArgument>()) a.name.lexeme: a};
    final animation = args['animation']?.argumentExpression;
    final builder = args['builder']?.argumentExpression;
    if (animation == null || !_isAnimationOfDouble(animation.staticType)) return;
    if (builder is! FunctionExpression) return;
    final params = builder.parameters?.parameters ?? const [];
    if (params.length != 2) return;

    final opacity = _returned(builder.body);
    if (opacity is! InstanceCreationExpression ||
        opacity.constructorName.name != null ||
        !isFlutterClass(opacity.constructorName.type.element, 'Opacity')) {
      return;
    }
    final opacityArgs = {
      for (final a in opacity.argumentList.arguments)
        if (a is NamedArgument) a.name.lexeme: a.argumentExpression,
    };
    if (opacityArgs.length != 2 || opacity.argumentList.arguments.length != 2) return;

    final value = opacityArgs['opacity'];
    final target = switch (value) {
      PrefixedIdentifier(:final prefix, :final identifier) when identifier.name == 'value' => prefix,
      PropertyAccess(:final target?, :final propertyName, isNullAware: false) when propertyName.name == 'value' =>
        target,
      _ => null,
    };
    if (target == null || !_samePath(target, animation)) return;

    final child = opacityArgs['child'];
    final childParam = params[1].declaredFragment?.element;
    if (child is! SimpleIdentifier || childParam == null || child.element != childParam) return;

    final builderArg = args['builder']!;
    final i = all.indexOf(builderArg);
    final deleteFrom = i + 1 < all.length ? builderArg.offset : all[i - 1].end;
    final deleteTo = i + 1 < all.length ? all[i + 1].offset : builderArg.end;
    final label = args['animation']!.name;
    final edits = [
      Edit(type.name.offset, type.name.length, 'FadeTransition'),
      Edit(label.offset, label.length, 'opacity'),
      Edit(deleteFrom, deleteTo - deleteFrom, ''),
    ];
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        'Use FadeTransition(opacity: ${animation.toSource()}, ...): AnimatedBuilder rebuilds this Opacity on every '
        'animation frame; FadeTransition updates the opacity of the existing layer with no rebuild.',
        edits: edits,
      ),
    );
  }

  static Expression? _returned(FunctionBody body) => switch (body) {
    ExpressionFunctionBody(:final expression) => expression,
    BlockFunctionBody(block: Block(statements: [ReturnStatement(:final expression)])) => expression,
    _ => null,
  };

  static bool _isAnimationOfDouble(DartType? type) =>
      type is InterfaceType &&
      type.nullabilitySuffix == NullabilitySuffix.none &&
      [
        type,
        ...type.allSupertypes,
      ].any((t) => isFlutterClass(t.element, 'Animation') && t.typeArguments.single.isDartCoreDouble);

  static bool _samePath(Expression a, Expression b) => switch ((a, b)) {
    (SimpleIdentifier a, SimpleIdentifier b) => a.element != null && a.element == b.element,
    (PrefixedIdentifier a, PrefixedIdentifier b) =>
      _samePath(a.prefix, b.prefix) && a.identifier.element != null && a.identifier.element == b.identifier.element,
    (PropertyAccess a, PropertyAccess b) =>
      !a.isNullAware &&
          !b.isNullAware &&
          a.target != null &&
          b.target != null &&
          _samePath(a.target!, b.target!) &&
          a.propertyName.element != null &&
          a.propertyName.element == b.propertyName.element,
    (ThisExpression _, ThisExpression _) => true,
    _ => false,
  };
}
