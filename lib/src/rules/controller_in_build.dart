import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../engine.dart';
import '../heat.dart';
import '../project.dart';

class ControllerInBuild extends Rule {
  @override
  final name = 'controller-in-build';
  @override
  final impact = 'high';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, project, findings));
    return findings;
  }
}

const _controllers = {
  'TextEditingController': 'the text and cursor are',
  'ScrollController': 'the scroll position is',
  'PageController': 'the current page is',
  'TabController': 'the selected tab is',
  'AnimationController': 'the animation is',
  'FocusNode': 'the focus is',
};

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
    final controller = _controllers.keys.where((c) => isFlutterClass(type, c)).firstOrNull;
    final key = isFlutterClass(type, 'GlobalKey');
    if (controller == null && !key) return;
    final cls = node.thisOrAncestorOfType<ClassDeclaration>()?.declaredFragment?.element;
    if (cls == null || !(isA(cls.thisType, 'Widget') || isA(cls.thisType, 'State'))) return;
    final hot = project.heat.at(node);
    if (hot.heat.index < Heat.build.index) return;
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        key
            ? 'A new GlobalKey is created ${hot.heat.when} (${hot.path}). Flutter then treats the subtree as new, '
                  'so its state is thrown away and rebuilt each time.\nCreate the key once, as a final field of the State.'
            : 'A new $controller is created ${hot.heat.when} (${hot.path}): ${_controllers[controller]} '
                  'lost on every rebuild, and the old one is never disposed.\nCreate it once in initState '
                  '(StatefulWidget) and dispose it in dispose().',
      ),
    );
  }
}
