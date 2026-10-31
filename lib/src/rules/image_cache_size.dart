import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';

import '../engine.dart';
import '../project.dart';

class ImageCacheSize extends Rule {
  @override
  final name = 'image-cache-size';
  @override
  final impact = 'high';

  @override
  List<Finding> check(ResolvedUnitResult unit, Project project) {
    final findings = <Finding>[];
    unit.unit.accept(_Visitor(this, unit, project, findings));
    return findings;
  }
}

const _safeFits = {'contain', 'scaleDown', 'fitWidth'};

class _Visitor extends RecursiveAstVisitor<void> {
  final Rule rule;
  final ResolvedUnitResult unit;
  final Project project;
  final List<Finding> findings;
  _Visitor(this.rule, this.unit, this.project, this.findings);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    final ctor = node.constructorName;
    if (ctor.name?.name != 'network' || !isFlutterClass(ctor.type.element, 'Image')) return;
    final args = {
      for (final a in node.argumentList.arguments)
        if (a is NamedArgument) a.name.lexeme: a,
    };
    final width = args['width'];
    if (width == null || args.containsKey('cacheWidth') || args.containsKey('cacheHeight')) return;
    if (!inListItem(node, project)) return;

    final w = width.argumentExpression;
    final literal = (w is IntegerLiteral && (w.value ?? 0) > 0) || (w is DoubleLiteral && w.value > 0);
    final fit = args['fit']?.argumentExpression;
    final safeFit =
        fit == null ||
        (fit is PrefixedIdentifier && fit.prefix.name == 'BoxFit' && _safeFits.contains(fit.identifier.name));
    final cover = fit is PrefixedIdentifier && fit.prefix.name == 'BoxFit' && fit.identifier.name == 'cover';
    final tiled = args.containsKey('repeat') || args.containsKey('centerSlice');
    final context = _contextName(node);
    final dpr = '${_prefix(ctor.type)}MediaQuery.devicePixelRatioOf(${context ?? 'context'})';
    final value = _scaled(w, dpr);
    final height = args['height']?.argumentExpression;

    if (literal && safeFit && !tiled && context != null) {
      final all = node.argumentList.arguments;
      final before = all[all.indexOf(width) - 1];
      final sep = unit.content.substring(before.end, width.offset);
      findings.add(
        Finding(
          rule,
          unit,
          node.offset,
          'Add cacheWidth so the image is decoded at its display size, not full size, for every list item.',
          edits: [Edit(width.end, 0, '${sep}cacheWidth: $value')],
        ),
      );
    } else {
      findings.add(
        Finding(
          rule,
          unit,
          node.offset,
          [
            if (cover) ...[
              'Image decoded at full size in a list. With BoxFit.cover each photo\'s shape decides which side fills',
              'the box (dpr = $dpr):',
              '  photos wider than the box: cacheHeight: ${height == null ? '(boxHeight * dpr).round()' : _scaled(height, 'dpr')}',
              '  photos taller than the box: cacheWidth: ${_scaled(w, 'dpr')}',
              '  mixed shapes: leave headroom, like cacheWidth: ${_scaled(w, 'dpr * 2')}',
            ] else ...[
              'Image decoded at full size in a list. Add `cacheWidth: $value`.',
              if (!literal) 'Check the width is never infinity or 0.',
              if (!safeFit || tiled)
                'With this fit/repeat the image can be drawn wider than width: use the largest drawn width.',
            ],
            if (context == null) 'Needs a BuildContext here.',
          ].join('\n'),
        ),
      );
    }
  }

  static String? _contextName(AstNode node) {
    for (AstNode? n = node.parent; n != null; n = n.parent) {
      final params = switch (n) {
        FunctionExpression(:final parameters) => parameters,
        MethodDeclaration(:final parameters) => parameters,
        _ => null,
      };
      for (final p in params?.parameters ?? const <FormalParameter>[]) {
        final e = p.declaredFragment?.element;
        if (e != null && e.name != null && e.name != '_' && isFlutterClass(e.type.element, 'BuildContext')) {
          return e.name;
        }
      }
      if (n is ClassDeclaration) {
        final cls = n.declaredFragment?.element;
        return cls != null && cls.allSupertypes.any((t) => isFlutterClass(t.element, 'State')) ? 'context' : null;
      }
    }
    return null;
  }

  static String _scaled(Expression e, String dpr) {
    final src = e.toSource();
    if (e.staticType?.nullabilitySuffix != NullabilitySuffix.question) return '($src * $dpr).round()';
    final promotable =
        e is SimpleIdentifier && (e.element is LocalVariableElement || e.element is FormalParameterElement);
    return '$src == null ? null : ($src${promotable ? '' : '!'} * $dpr).round()';
  }

  static String _prefix(NamedType type) => type.importPrefix == null ? '' : '${type.importPrefix!.name.lexeme}.';
}
