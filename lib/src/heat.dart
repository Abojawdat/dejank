import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'engine.dart';
import 'project.dart';

enum Heat {
  cold('once in a while'),
  startup('at startup'),
  event('on every event'),
  build('on every build'),
  keystroke('on every keystroke'),
  item('for every list item'),
  frame('on every frame');

  final String when;
  const Heat(this.when);
}

class Hot {
  final Heat heat;
  final List<String> chain;
  const Hot(this.heat, this.chain);

  String get path =>
      chain.length > 6 ? [...chain.take(2), '…', ...chain.skip(chain.length - 3)].join(' → ') : chain.join(' → ');
}

const _frameGestures = {
  'onPanUpdate',
  'onScaleUpdate',
  'onVerticalDragUpdate',
  'onHorizontalDragUpdate',
  'onPointerMove',
  'onPointerHover',
  'onDragUpdate',
  'onNotification',
};

const _builderArgs = {
  'builder',
  'layoutBuilder',
  'transitionBuilder',
  'pageBuilder',
  'loadingBuilder',
  'frameBuilder',
  'placeholderBuilder',
};

const _runNow = {
  'map',
  'where',
  'forEach',
  'expand',
  'fold',
  'reduce',
  'any',
  'every',
  'firstWhere',
  'lastWhere',
  'singleWhere',
  'indexWhere',
  'sort',
  'removeWhere',
  'retainWhere',
  'takeWhile',
  'skipWhile',
  'generate',
  'setState',
  'putIfAbsent',
  'update',
  'updateAll',
  'replaceAllMapped',
  'splitMapJoin',
};

class HeatMap {
  final _decl = <Element, AstNode>{};
  final _base = <AstNode, Heat>{};
  final _labels = <AstNode, String>{};
  final _async = <AstNode>{};
  final _edges = <AstNode, Map<AstNode, bool>>{};
  final _calls = <(AstNode, Element, bool)>[];
  final _creates = <(AstNode, InterfaceElement, bool)>[];
  final _stateOf = <Element, InterfaceElement>{};
  final _tearOffs = <(Element, Heat, String)>[];
  final _heat = <AstNode, Heat>{};
  final _from = <AstNode, AstNode>{};

  HeatMap(List<ResolvedUnitResult> units) {
    final collector = _Collector(this);
    for (final unit in units) {
      unit.unit.accept(collector);
    }
    void edge(AstNode from, AstNode? to, bool conditional) {
      if (to == null) return;
      final edges = _edges.putIfAbsent(from, () => {});
      edges[to] = (edges[to] ?? true) && conditional;
    }

    for (final (from, to, conditional) in _calls) {
      edge(from, _decl[to], conditional);
    }
    for (final (from, widget, conditional) in _creates) {
      final build = (_stateOf[widget] ?? widget).getMethod('build')?.baseElement;
      edge(from, build == null ? null : _decl[build], conditional);
    }
    for (final (e, heat, label) in _tearOffs) {
      final decl = _decl[e];
      if (decl != null && (_base[decl]?.index ?? -1) < heat.index) {
        _base[decl] = heat;
        _labels[decl] = '$label: ${_labels[decl] ?? ''}';
      }
    }
    final todo = [..._base.keys];
    for (final n in todo) {
      _heat[n] = _base[n]!;
    }
    while (todo.isNotEmpty) {
      final n = todo.removeLast();
      for (final MapEntry(key: next, value: conditional) in (_edges[n] ?? const {}).entries) {
        var h = _heat[n]!;
        if (conditional && h == Heat.frame) h = Heat.event;
        if (_async.contains(next) && h.index > Heat.event.index) h = Heat.event;
        if ((_heat[next]?.index ?? -1) >= h.index) continue;
        _heat[next] = h;
        _from[next] = n;
        todo.add(next);
      }
    }
  }

  Hot at(AstNode node) {
    final exec = executableOf(node);
    var hot = exec == null ? const Hot(Heat.cold, []) : Hot(_heat[exec] ?? Heat.cold, _chain(exec));
    if (hot.heat.index < Heat.item.index && inListItem(node)) hot = Hot(Heat.item, [...hot.chain, 'list item']);
    return hot;
  }

  List<String> _chain(AstNode exec) {
    final out = <String>[];
    final seen = <AstNode>{};
    AstNode? root;
    for (AstNode? n = exec; n != null && seen.add(n); n = _from[n]) {
      root = n;
      final label = _labels[n];
      if (label != null && label.isNotEmpty && (out.isEmpty || out.first != label)) out.insert(0, label);
    }
    if (root is FunctionExpression) {
      final outer = _labels[executableOf(root.parent!)];
      if (outer != null && outer.isNotEmpty) out.insert(0, outer);
    }
    return out;
  }

  static AstNode? executableOf(AstNode node) {
    for (AstNode? n = node; n != null; n = n.parent) {
      if (n is MethodDeclaration || n is FunctionDeclaration || n is ConstructorDeclaration) return n;
      if (n is FunctionExpression && n.parent is! FunctionDeclaration) return n;
    }
    return null;
  }
}

bool isA(DartType? type, String flutterClass) =>
    type is InterfaceType &&
    (isFlutterClass(type.element, flutterClass) ||
        type.element.allSupertypes.any((s) => isFlutterClass(s.element, flutterClass)));

bool _app(Element? e) {
  final uri = e?.library?.uri;
  return uri != null && !uri.isScheme('dart') && !uri.toString().startsWith('package:flutter/');
}

bool _conditional(AstNode node, AstNode exec) {
  for (AstNode? child = node, n = node.parent; n != null && child != exec; child = n, n = n.parent) {
    final branch = switch (n) {
      IfStatement(:final expression) => child != expression,
      IfElement(:final expression) => child != expression,
      ConditionalExpression(:final condition) => child != condition,
      BinaryExpression(:final operator, :final rightOperand) =>
        (operator.lexeme == '&&' || operator.lexeme == '||' || operator.lexeme == '??') && child == rightOperand,
      SwitchMember() || SwitchExpressionCase() || CatchClause() => true,
      _ => false,
    };
    if (branch) return true;
  }
  return false;
}

enum _Use { source, inherit, callback }

class _Collector extends RecursiveAstVisitor<void> {
  final HeatMap map;
  _Collector(this.map);

  final _stack = <AstNode>[];
  String? _class;

  void _inside(AstNode node, String label, FunctionBody? body, void Function() visit) {
    if (label.isNotEmpty) map._labels[node] = label;
    if (body != null && body.isAsynchronous) map._async.add(node);
    _stack.add(node);
    visit();
    _stack.removeLast();
  }

  void _named(String? name, void Function() visit) {
    final outer = _class;
    _class = name;
    visit();
    _class = outer;
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      _named(node.name.lexeme, () => super.visitMixinDeclaration(node));

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) =>
      _named(node.name?.lexeme ?? 'extension', () => super.visitExtensionDeclaration(node));

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final e = node.declaredFragment?.element;
    if (e != null) {
      for (final s in e.allSupertypes) {
        final widget = s.typeArguments.firstOrNull?.element;
        if (isFlutterClass(s.element, 'State') && widget != null) map._stateOf[widget] = e;
      }
    }
    _named(e?.name, () => super.visitClassDeclaration(node));
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final e = node.declaredFragment?.element;
    if (e != null) map._decl[e.baseElement] = node;
    final cls = e?.enclosingElement;
    if (cls is InterfaceElement) {
      final type = cls.thisType;
      if (node.name.lexeme == 'build' && (isA(type, 'Widget') || isA(type, 'State'))) map._base[node] = Heat.build;
      if (node.name.lexeme == 'paint' && isA(type, 'CustomPainter')) map._base[node] = Heat.frame;
    }
    _inside(node, '${_class ?? ''}.${node.name.lexeme}', node.body, () => super.visitMethodDeclaration(node));
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final e = node.declaredFragment?.element;
    if (e != null) map._decl[e.baseElement] = node;
    if (node.name.lexeme == 'main' && node.parent is CompilationUnit) map._base[node] = Heat.startup;
    _inside(node, node.name.lexeme, node.functionExpression.body, () => super.visitFunctionDeclaration(node));
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    final e = node.declaredFragment?.element;
    if (e != null) map._decl[e.baseElement] = node;
    _inside(node, '${_class ?? ''}()', null, () => super.visitConstructorDeclaration(node));
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is FunctionDeclaration) return super.visitFunctionExpression(node);
    final (use, heat, label) = _position(node);
    if (use == _Use.source) {
      map._base[node] = heat!;
    } else if (use == _Use.inherit && _stack.isNotEmpty) {
      map._edges.putIfAbsent(_stack.last, () => {})[node] = _conditional(node, _stack.last);
    }
    _inside(node, label ?? '', node.body, () => super.visitFunctionExpression(node));
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final cls = node.constructorName.type.element;
    if (_stack.isNotEmpty && cls is InterfaceElement && _app(cls) && !node.isConst) {
      final conditional = _conditional(node, _stack.last);
      if (isA(cls.thisType, 'Widget')) {
        map._creates.add((_stack.last, cls, conditional));
      } else if (node.constructorName.element case final Element c) {
        map._calls.add((_stack.last, c.baseElement, conditional));
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final e = node.element;
    if (_stack.isEmpty || e is! ExecutableElement || !_app(e)) return;
    final parent = node.parent;
    final invoked =
        e is PropertyAccessorElement ||
        (parent is MethodInvocation && parent.methodName == node) ||
        (parent is FunctionExpressionInvocation && parent.function == node);
    if (invoked) {
      map._calls.add((_stack.last, e.baseElement, _conditional(node, _stack.last)));
      return;
    }
    final (use, heat, label) = _position(node);
    if (use == _Use.source) map._tearOffs.add((e.baseElement, heat!, label!));
    if (use == _Use.inherit) map._calls.add((_stack.last, e.baseElement, _conditional(node, _stack.last)));
  }

  (_Use, Heat?, String?) _position(Expression node) {
    AstNode child = node;
    var parent = node.parent;
    while (parent is ParenthesizedExpression ||
        parent is AsExpression ||
        (parent is ConditionalExpression && parent.condition != child) ||
        (parent is BinaryExpression && parent.operator.lexeme == '??')) {
      child = parent!;
      parent = parent.parent;
    }
    if (parent is FunctionExpressionInvocation) return (_Use.inherit, null, null);
    if (parent is NamedArgument) {
      final name = parent.name.lexeme;
      final owner = parent.parent?.parent;
      final heat = _source(name, owner);
      if (heat != null) return (_Use.source, heat, name);
      return (_builderArgs.contains(name) ? _Use.inherit : _Use.callback, null, name);
    }
    if (parent is! ArgumentList) return (_Use.callback, null, null);
    final call = parent.parent;
    if (call is MethodInvocation) {
      final name = call.methodName.name;
      final target = call.realTarget?.staticType;
      if (name == 'addListener') {
        final heat = isA(target, 'Animation') || isA(target, 'ScrollController') || isA(target, 'ScrollPosition')
            ? Heat.frame
            : isA(target, 'TextEditingController')
            ? Heat.keystroke
            : Heat.event;
        return (_Use.source, heat, 'addListener');
      }
      if (name == 'listen') return (_Use.source, Heat.event, 'listen');
      if (name == 'periodic') return (_Use.source, Heat.event, 'Timer.periodic');
      if (name == 'createTicker') return (_Use.source, Heat.frame, 'ticker');
      return (_runNow.contains(name) ? _Use.inherit : _Use.callback, null, null);
    }
    if (call is InstanceCreationExpression) {
      final cls = call.constructorName.type.element;
      final ctor = call.constructorName.name?.name;
      if (isFlutterClass(cls, 'SliverChildBuilderDelegate')) return (_Use.source, Heat.item, 'builder');
      if (isFlutterClass(cls, 'Ticker')) return (_Use.source, Heat.frame, 'ticker');
      if (cls?.name == 'Timer' && ctor == 'periodic') return (_Use.source, Heat.event, 'Timer.periodic');
      if (ctor == 'generate') return (_Use.inherit, null, null);
    }
    return (_Use.callback, null, null);
  }

  Heat? _source(String name, AstNode? owner) {
    final cls = switch (owner) {
      InstanceCreationExpression(:final constructorName) => constructorName.type.element,
      _ => null,
    };
    if (name == 'itemBuilder' || name == 'separatorBuilder') {
      final flutter = cls != null && !_app(cls);
      return !flutter || listWidgets.any((c) => isFlutterClass(cls, c)) ? Heat.item : null;
    }
    if (name == 'builder') {
      if (isFlutterClass(cls, 'AnimatedBuilder') || isFlutterClass(cls, 'TweenAnimationBuilder')) return Heat.frame;
      if (owner is InstanceCreationExpression &&
          (isFlutterClass(cls, 'ListenableBuilder') || isFlutterClass(cls, 'ValueListenableBuilder'))) {
        final listenable = owner.argumentList.arguments
            .whereType<NamedArgument>()
            .where((a) => a.name.lexeme == 'listenable' || a.name.lexeme == 'valueListenable')
            .firstOrNull;
        if (isA(listenable?.argumentExpression.staticType, 'Animation')) return Heat.frame;
      }
      return null;
    }
    if (_frameGestures.contains(name)) return Heat.frame;
    if (name == 'onChanged') return Heat.keystroke;
    return null;
  }
}
