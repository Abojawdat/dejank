import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../engine.dart';
import '../project.dart';

class SerialAwaitsMain extends Rule {
  @override
  final name = 'serial-awaits-main';
  @override
  final impact = 'medium';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    for (final d in unit.unit.declarations) {
      if (d is! FunctionDeclaration || d.name.lexeme != 'main') continue;
      final body = d.functionExpression.body;
      if (body is! BlockFunctionBody) continue;
      final statements = body.block.statements;
      final runApp = statements.indexWhere((s) => (_FindRunApp()..visit(s)).found);
      if (runApp == -1) continue;

      var run = <_Await>[];
      void flush() {
        if (run.length >= 2) findings.add(Finding(this, unit, run.first.statement.offset, _message(unit, run)));
        run = [];
      }

      for (final s in statements.take(runApp)) {
        final a = _Await.of(s, unit.libraryElement.uri);
        if (a == null) {
          flush();
          continue;
        }
        if (run.any(a.dependsOn)) flush();
        run.add(a);
      }
      flush();
    }
    return findings;
  }

  static String _message(ResolvedUnitResult unit, List<_Await> run) {
    final calls = [for (final a in run) '    ${unit.content.substring(a.future.offset, a.future.end)},'];
    final vars = [for (final a in run) a.variable ?? '_'];
    final keyword = run.every((a) => a.keyword == 'final' || a.variable == null) ? 'final' : 'var';
    final code = vars.every((v) => v == '_')
        ? ['  await Future.wait([', ...calls, '  ]);']
        : ['  $keyword (${vars.join(', ')}) = await (', ...calls, '  ).wait;'];
    return [
      '${run.length} awaits run one after another before runApp, so the first frame waits for each in turn.',
      'If none of them needs another, start them together:',
      ...code,
      'Keep any call that must finish first (like Firebase.initializeApp before other Firebase calls) above it.',
    ].join('\n');
  }
}

class _Await {
  final Statement statement;
  final Expression future;

  final String? variable;
  final String? keyword;
  final Element? declared;

  final Set<Object> names;

  _Await(this.statement, this.future, this.variable, this.keyword, this.declared, this.names);

  static _Await? of(Statement s, Uri app) {
    if (s case ExpressionStatement(expression: AwaitExpression(:final expression))) {
      final names = _Names.of(expression, app);
      return names == null ? null : _Await(s, expression, null, null, null, names);
    }
    if (s case VariableDeclarationStatement(
      variables: VariableDeclarationList(:final variables, :final keyword, :final type),
    ) when variables.length == 1 && keyword?.lexeme != 'late') {
      final v = variables.single;
      final init = v.initializer;
      if (init is! AwaitExpression) return null;
      final names = _Names.of(init.expression, app);
      if (names == null) return null;
      final variable = type == null ? v.name.lexeme : '${type.toSource()} ${v.name.lexeme}';
      return _Await(s, init.expression, variable, keyword?.lexeme, v.declaredFragment?.element, names);
    }
    return null;
  }

  bool dependsOn(_Await earlier) => names.contains(earlier.declared) || names.any(earlier.names.contains);
}

class _Names extends RecursiveAstVisitor<void> {
  final Uri app;
  final names = <Object>{};
  var callsAppCode = false;
  _Names(this.app);

  static Set<Object>? of(Expression e, Uri app) {
    final v = _Names(app);
    e.accept(v);
    return v.callsAppCode ? null : v.names;
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final e = node.element?.baseElement;
    if (e == null) return;
    names.add(e);
    if (node.name.startsWith('Firebase')) names.add('Firebase');
    final runsCode =
        e is InterfaceElement || (e is ExecutableElement && !(e is PropertyAccessorElement && e.isOriginVariable));
    if (runsCode && _sameApp(e.library?.uri)) callsAppCode = true;
  }

  @override
  void visitNamedType(NamedType node) {
    super.visitNamedType(node);
    final e = node.element;
    if (e == null) return;
    names.add(e);
    if (e is InterfaceElement && _sameApp(e.library.uri)) callsAppCode = true;
  }

  bool _sameApp(Uri? uri) =>
      uri != null &&
      (app.isScheme('package')
          ? uri.isScheme('package') && uri.pathSegments.first == app.pathSegments.first
          : uri.isScheme('file'));
}

class _FindRunApp extends RecursiveAstVisitor<void> {
  var found = false;

  void visit(AstNode node) => node.accept(this);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final e = node.methodName.element;
    if (node.methodName.name == 'runApp' && (e?.library?.uri.toString().startsWith('package:flutter/') ?? false)) {
      found = true;
    }
    super.visitMethodInvocation(node);
  }
}
