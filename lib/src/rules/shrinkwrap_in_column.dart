import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../engine.dart';
import '../project.dart';

class ShrinkWrapInColumn extends Rule {
  @override
  final name = 'shrinkwrap-in-column';
  @override
  final impact = 'high';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, findings));
    return findings;
  }
}

const _lazy = {
  'ListView': {'builder', 'separated'},
  'GridView': {'builder'},
};

const _unbounded = {'Column', 'SingleChildScrollView', 'ListView', 'GridView', 'CustomScrollView'};

const _passThrough = {
  'Padding',
  'Card',
  'DecoratedBox',
  'ClipRRect',
  'ClipRect',
  'Material',
  'SafeArea',
  'Align',
  'Center',
  'Opacity',
  'Visibility',
  'SliverToBoxAdapter',
  'Builder',
  'LayoutBuilder',
  'StreamBuilder',
  'FutureBuilder',
  'ValueListenableBuilder',
  'ListenableBuilder',
  'AnimatedBuilder',
};

const _statePackages = {'flutter_bloc', 'provider', 'flutter_riverpod', 'hooks_riverpod', 'get', 'flutter_mobx'};

const _smallCount = 20;

class _Visitor extends RecursiveAstVisitor<void> {
  final Rule rule;
  final ResolvedUnitResult unit;
  final List<Finding> findings;
  _Visitor(this.rule, this.unit, this.findings);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    final ctor = node.constructorName;
    final lazy = _lazy.entries.any(
      (e) => isFlutterClass(ctor.type.element, e.key) && e.value.contains(ctor.name?.name),
    );
    if (!lazy) return;
    final args = {
      for (final a in node.argumentList.arguments)
        if (a is NamedArgument) a.name.lexeme: a.argumentExpression,
    };
    final shrinkWrap = args['shrinkWrap'];
    if (shrinkWrap is! BooleanLiteral || !shrinkWrap.value) return;
    if (!_vertical(args)) return;
    if (args['itemCount'] case IntegerLiteral(:final value?) when value <= _smallCount) return;

    final parent = _unboundedParent(node);
    if (parent == null) return;
    final list = '${ctor.type.name.lexeme}.${ctor.name!.name}';
    final sliver = '${ctor.type.name.lexeme == 'ListView' ? 'SliverList' : 'SliverGrid'}.${ctor.name!.name}';
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        [
          'shrinkWrap in a $parent builds every item at once: $list is no longer lazy.',
          if (parent == 'Column') 'If it is the only list here: wrap it in Expanded and remove shrinkWrap.',
          'If it scrolls together with other content: use CustomScrollView(slivers: [..., $sliver(...)]),',
          'with SliverToBoxAdapter for the other widgets, and remove shrinkWrap.',
        ].join('\n'),
      ),
    );
  }

  static String? _unboundedParent(InstanceCreationExpression list) {
    for (var n = list.parent; n != null; n = n.parent) {
      switch (n) {
        case InstanceCreationExpression(:final constructorName):
          final e = constructorName.type.element;
          if (_unbounded.any((c) => isFlutterClass(e, c))) {
            final args = {
              for (final a in n.argumentList.arguments)
                if (a is NamedArgument) a.name.lexeme: a.argumentExpression,
            };
            if (e!.name == 'Column') return _unboundedParent(n) ?? 'Column';
            return _vertical(args) ? e.name : null;
          }
          if (!_passesThrough(e)) return null;
        case NamedArgument() ||
            ArgumentList() ||
            ListLiteral() ||
            IfElement() ||
            ForElement() ||
            ConditionalExpression() ||
            ParenthesizedExpression() ||
            FunctionExpression() ||
            ExpressionFunctionBody() ||
            BlockFunctionBody() ||
            Block() ||
            ReturnStatement() ||
            IfStatement() ||
            SwitchStatement() ||
            SwitchMember() ||
            SwitchExpression() ||
            SwitchExpressionCase():
          continue;
        default:
          return null;
      }
    }
    return null;
  }

  static bool _passesThrough(Element? e) =>
      _passThrough.any((c) => isFlutterClass(e, c)) ||
      (e is InterfaceElement && _statePackages.contains(e.library.uri.pathSegments.firstOrNull));

  static bool _vertical(Map<String, Expression> args) => switch (args['scrollDirection']) {
    null => true,
    PrefixedIdentifier(:final prefix, :final identifier) => prefix.name == 'Axis' && identifier.name == 'vertical',
    _ => false,
  };
}
