import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../engine.dart';
import '../project.dart';

class IntrinsicInList extends Rule {
  @override
  final name = 'intrinsic-in-list';
  @override
  final impact = 'medium';

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
    final height = isFlutterClass(type, 'IntrinsicHeight');
    if (!height && !isFlutterClass(type, 'IntrinsicWidth')) return;
    if (!inListItem(node, project)) return;
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        [
          '${type!.name} lays out its child twice (measure, then real) for every list item.',
          height
              ? 'Use a fixed height instead: SizedBox(height: 72, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, ...))'
              : 'Use a fixed width instead: SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, ...))',
        ].join('\n'),
      ),
    );
  }
}
