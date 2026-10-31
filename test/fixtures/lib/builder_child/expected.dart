import 'dart:math';

import 'package:flutter/material.dart';

class Spinner extends StatefulWidget {
  const Spinner({super.key});

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))
    ..repeat();
  final String label = 'refresh';
  int _count = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color _color() => Colors.blue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.rotate(
            angle: _c.value * 2 * pi,
            child: child!,
          ),
          child: Container( // LINT
              width: 48,
              height: 48,
              color: Colors.blue,
              child: Text(label),
            ),
        ),

        // Must not change.
        // Reads the animation.
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Opacity(opacity: _c.value, child: Container(color: Colors.red, child: Text('${_c.value}'))),
        ),
        // Reads a field that can change.
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Transform.scale(scale: _c.value, child: Container(color: Colors.red, child: Text('$_count'))),
        ),
        // Already uses child.
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.scale(scale: _c.value, child: child),
          child: Container(color: Colors.green, child: const Text('x')),
        ),
        // Reads the builder's context.
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) =>
              Transform.scale(scale: _c.value, child: Container(color: Theme.of(context).primaryColor, child: Text(label))),
        ),
        // Calls the app's own code, which could read the animation.
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Transform.scale(scale: _c.value, child: Container(color: _color(), child: Text(label))),
        ),
        TextButton(onPressed: () => setState(() => _count++), child: const Text('+')),
      ],
    );
  }
}
