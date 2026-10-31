import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../engine.dart';
import '../project.dart';

class IntrinsicInList extends Rule {
  @override
  final name = 'intrinsic-in-list';
  @override
  final impact = 'low';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, project, findings));
    return findings;
  }
}

bool _intrinsic(Element? e) => isFlutterClass(e, 'IntrinsicHeight') || isFlutterClass(e, 'IntrinsicWidth');

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
    if (!_intrinsic(type) || !inListItem(node, project)) return;
    final outer = node.thisOrAncestorMatching(
      (n) => n != node && n is InstanceCreationExpression && _intrinsic(n.constructorName.type.element),
    );
    if (outer is InstanceCreationExpression) {
      findings.add(
        Finding(
          rule,
          unit,
          node.offset,
          [
            '${type!.name} inside ${outer.constructorName.type.name.lexeme}: each level lays out its child twice, so this',
            'subtree is laid out 4 times for every list item. Remove one of them (usually the inner one).',
          ].join('\n'),
          impact: 'high',
        ),
      );
    } else if (isFlutterClass(type, 'IntrinsicHeight')) {
      findings.add(
        Finding(
          rule,
          unit,
          node.offset,
          [
            'IntrinsicHeight lays out its child twice for every list item that is built.',
            'If the items can have a known height, SizedBox(height: ...) skips the extra pass.',
            'If the height depends on the content, keeping it is fine in a lazy list: only visible items pay.',
          ].join('\n'),
        ),
      );
    }
  }
}
