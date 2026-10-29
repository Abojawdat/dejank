import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../engine.dart';

/// `MediaQuery.of(context).size` → `MediaQuery.sizeOf(context)`.
///
/// `.of` makes the widget rebuild when *anything* in MediaQueryData changes, e.g. on every frame of the
/// keyboard animation. `sizeOf` rebuilds only when the size changes. Rewritten only when exactly one
/// property is read straight off `.of(context)`; anything else is left alone.
class MediaQueryOf extends Rule {
  @override
  final name = 'mediaquery-of';
  @override
  final impact = 'high';

  /// MediaQueryData getters that have a matching `MediaQuery.<name>Of(context)` returning the same value.
  static const _props = {
    'size', 'orientation', 'devicePixelRatio', 'textScaleFactor', 'textScaler', 'platformBrightness',
    'padding', 'viewInsets', 'systemGestureInsets', 'viewPadding', 'alwaysUse24HourFormat',
    'accessibleNavigation', 'invertColors', 'highContrast', 'onOffSwitchLabels', 'disableAnimations',
    'boldText', 'supportsAnnounce', 'navigationMode', 'gestureSettings', 'displayFeatures', //
  };

  @override
  List<Finding> check(ResolvedUnitResult unit) {
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
    if (method == null || !MediaQueryOf._props.contains(method)) return;
    read = read.parent as Expression;

    // `.size.width` / `.size.height` → `widthOf` / `heightOf` (Flutter 3.35+), even narrower.
    final sub = method == 'size' ? _readOf(read) : null;
    if ((sub == 'width' || sub == 'height') && _hasStatic(mediaQuery, '${sub}Of')) {
      method = sub!;
      read = read.parent as Expression;
    }

    final replacement = '${method}Of';
    if (!_hasStatic(mediaQuery, replacement)) return; // older Flutter without this method
    final args = unit.content.substring(node.argumentList.offset, node.argumentList.end);
    findings.add(
      Finding(
        rule,
        unit,
        node.offset,
        'Use MediaQuery.$replacement(context): rebuilds only when `$method` changes, '
        'not on every MediaQuery change (like each frame of the keyboard animation).',
        [Edit(node.methodName.offset, read.end - node.methodName.offset, '$replacement$args')],
      ),
    );
  }

  /// Name of the property read directly off [e] (`e.name`), or null.
  static String? _readOf(Expression e) {
    final parent = e.parent;
    if (parent is PropertyAccess && parent.target == e && !parent.isNullAware) {
      return parent.propertyName.name;
    }
    return null;
  }

  static bool _hasStatic(InterfaceElement c, String name) => c.getMethod(name)?.isStatic ?? false;
}
