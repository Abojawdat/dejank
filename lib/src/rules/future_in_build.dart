import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../engine.dart';
import '../heat.dart';
import '../project.dart';

class FutureInBuild extends Rule {
  @override
  final name = 'future-in-build';
  @override
  final impact = 'high';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, project, findings));
    return findings;
  }
}

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
    final future = isFlutterClass(type, 'FutureBuilder');
    if (!future && !isFlutterClass(type, 'StreamBuilder')) return;
    final arg = node.argumentList.arguments
        .whereType<NamedArgument>()
        .where((a) => a.name.lexeme == (future ? 'future' : 'stream'))
        .firstOrNull;
    final value = arg?.argumentExpression;
    final created = switch (value) {
      MethodInvocation(:final methodName) => methodName.name != 'runOnce',
      FunctionExpressionInvocation() || InstanceCreationExpression() => true,
      _ => false,
    };
    if (!created) return;
    final hot = project.heat.at(node);
    if (hot.heat.index < Heat.build.index) return;
    findings.add(
      Finding(
        rule,
        unit,
        value!.offset,
        future
            ? 'A new Future is created ${hot.heat.when} (${hot.path}), so FutureBuilder starts over each time: it '
                  'shows the loading state again and the work runs again.\nCreate the Future once (in initState), '
                  'keep it in a field and pass the field here.'
            : 'A new Stream is created ${hot.heat.when} (${hot.path}), so StreamBuilder subscribes again each time '
                  'and loses the last value.\nCreate the stream once (in initState), keep it in a field and pass the '
                  'field here.',
      ),
    );
  }
}
