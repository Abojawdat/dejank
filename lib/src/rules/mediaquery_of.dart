import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../engine.dart';
import '../project.dart';

class MediaQueryOf extends Rule {
  @override
  final name = 'mediaquery-of';
  @override
  final impact = 'high';

  static const _props = {
    'size',
    'orientation',
    'devicePixelRatio',
    'textScaleFactor',
    'textScaler',
    'platformBrightness',
    'padding',
    'viewInsets',
    'systemGestureInsets',
    'viewPadding',
    'alwaysUse24HourFormat',
    'accessibleNavigation',
    'invertColors',
    'highContrast',
    'onOffSwitchLabels',
    'disableAnimations',
    'boldText',
    'supportsAnnounce',
    'navigationMode',
    'gestureSettings',
    'displayFeatures',
  };

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
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    final of = node.methodName.element;
    if (node.methodName.name != 'of' || of is! MethodElement || !of.isStatic) return;
    final mediaQuery = of.enclosingElement;
    if (!isFlutterClass(mediaQuery, 'MediaQuery')) return;
    mediaQuery as InterfaceElement;

    Expression read = node;
    var method = _readOf(read);
    if (method == null) return _stored(node, mediaQuery);
    if (!MediaQueryOf._props.contains(method)) return;
    read = read.parent as Expression;

    final sub = method == 'size' ? _readOf(read) : null;
    if ((sub == 'width' || sub == 'height') && _hasStatic(mediaQuery, '${sub}Of')) {
      method = sub!;
      read = read.parent as Expression;
    }

    final replacement = '${method}Of';
    if (!_hasStatic(mediaQuery, replacement)) return;
    final args = unit.content.substring(node.argumentList.offset, node.argumentList.end);
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        method == 'viewInsets'
            ? 'Use MediaQuery.viewInsetsOf(context): rebuilds only when `viewInsets` changes, not on other '
                  'MediaQuery changes. The keyboard changes viewInsets on every frame, so this saves little.'
            : 'Use MediaQuery.$replacement(context): rebuilds only when `$method` changes, '
                  'not on every MediaQuery change (like each frame of the keyboard animation).',
        edits: [Edit(node.methodName.offset, read.end - node.methodName.offset, '$replacement$args')],
        impact: method == 'viewInsets' ? 'low' : null,
      ),
    );
  }

  void _stored(MethodInvocation node, InterfaceElement mediaQuery) {
    final declaration = node.parent;
    final list = declaration?.parent;
    final statement = list?.parent;
    if (declaration is! VariableDeclaration ||
        declaration.initializer != node ||
        list is! VariableDeclarationList ||
        list.variables.length != 1 ||
        statement is! VariableDeclarationStatement) {
      return;
    }
    final variable = declaration.declaredFragment?.element;
    final scope = statement.parent;
    if (variable == null || scope == null) return;
    final uses = <SimpleIdentifier>[];
    scope.accept(_References(variable, uses));
    if (uses.isEmpty) return;
    final target = unit.content.substring(node.target!.offset, node.target!.end);
    final args = unit.content.substring(node.argumentList.offset, node.argumentList.end);
    final edits = <Edit>[];
    final read = <String>{};
    var later = false;
    for (final use in uses) {
      final property = switch (use.parent) {
        PrefixedIdentifier(:final prefix, :final identifier) when prefix == use => identifier,
        PropertyAccess(:final target, :final propertyName) when target == use => propertyName,
        _ => null,
      };
      if (property == null || !MediaQueryOf._props.contains(property.name)) return;
      var method = property.name;
      var end = property.end;
      final outer = use.parent!.parent;
      if (method == 'size' && outer is PropertyAccess && outer.target == use.parent) {
        final sub = outer.propertyName.name;
        if ((sub == 'width' || sub == 'height') && _hasStatic(mediaQuery, '${sub}Of')) {
          method = sub;
          end = outer.end;
        }
      }
      if (!_hasStatic(mediaQuery, '${method}Of')) return;
      later |= use.thisOrAncestorOfType<FunctionBody>() != statement.thisOrAncestorOfType<FunctionBody>();
      read.add(method);
      edits.add(Edit(use.offset, end - use.offset, '$target.${method}Of$args'));
    }
    final lineStart = unit.content.lastIndexOf('\n', statement.offset) + 1;
    final lineEnd = unit.content.indexOf('\n', statement.end);
    final ownLine = unit.content.substring(lineStart, statement.offset).trim().isEmpty;
    final names = [for (final m in read) '$target.${m}Of$args'];
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        [
          'Saving MediaQuery.of(context) in `${declaration.name.lexeme}` still rebuilds on every MediaQuery change, '
              'but only ${read.join(', ')} ${read.length == 1 ? 'is' : 'are'} read.',
          'Use ${names.join(', ')} instead${later ? ' (some reads are in a callback: read the value in build and '
                    'keep it in a variable there)' : ''}.',
        ].join('\n'),
        edits: later
            ? const []
            : [
                ...edits,
                ownLine && lineEnd != -1
                    ? Edit(lineStart, lineEnd + 1 - lineStart, '')
                    : Edit(statement.offset, statement.length, ''),
              ],
      ),
    );
  }

  static String? _readOf(Expression e) {
    final parent = e.parent;
    if (parent is PropertyAccess && parent.target == e && !parent.isNullAware) {
      return parent.propertyName.name;
    }
    return null;
  }

  static bool _hasStatic(InterfaceElement c, String name) => c.getMethod(name)?.isStatic ?? false;
}

class _References extends RecursiveAstVisitor<void> {
  final Element variable;
  final List<SimpleIdentifier> into;
  _References(this.variable, this.into);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.element == variable && !node.inDeclarationContext()) into.add(node);
  }
}
