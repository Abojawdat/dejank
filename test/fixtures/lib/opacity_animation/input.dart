import 'package:flutter/material.dart';

class Sample extends StatefulWidget {
  const Sample({super.key, required this.fade});
  final Animation<double> fade;

  @override
  State<Sample> createState() => _SampleState();
}

class _SampleState extends State<Sample> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  late final _curved = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  final _notifier = ValueNotifier<double>(1);

  @override
  void dispose() {
    _controller.dispose();
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder( // LINT
          animation: _controller,
          builder: (context, child) => Opacity(opacity: _controller.value, child: child),
          child: const Text('a'),
        ),
        AnimatedBuilder( // LINT
          animation: _curved,
          builder: (context, child) {
            return Opacity(opacity: _curved.value, child: child);
          },
          child: const Text('b'),
        ),
        AnimatedBuilder(animation: widget.fade, child: const Text('c'), builder: (_, child) => Opacity(opacity: widget.fade.value, child: child)), // LINT
        AnimatedBuilder( // LINT
          animation: _controller,
          builder: (context, child) => Opacity(opacity: _controller.value, child: child),
        ),

        // Must not change.
        // Opacity reads a different animation.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(opacity: _curved.value, child: child),
          child: const Text('d'),
        ),
        // Math on the value.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(opacity: 1 - _controller.value, child: child),
          child: const Text('e'),
        ),
        // Child is built inside the builder, so it may use the value too.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(opacity: _controller.value, child: Text('${_controller.value}')),
        ),
        // Builder does more than Opacity.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Padding(
            padding: EdgeInsets.all(_controller.value),
            child: Opacity(opacity: _controller.value, child: child),
          ),
          child: const Text('f'),
        ),
        // Extra Opacity argument.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(opacity: _controller.value, alwaysIncludeSemantics: true, child: child),
          child: const Text('g'),
        ),
        // Not an Animation<double>: FadeTransition can't take it.
        AnimatedBuilder(
          animation: _notifier,
          builder: (context, child) => Opacity(opacity: _notifier.value, child: child),
          child: const Text('h'),
        ),
        FadeTransition(opacity: _controller, child: const Text('i')),
      ],
    );
  }
}
