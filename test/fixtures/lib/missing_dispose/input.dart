import 'dart:async';

import 'package:flutter/material.dart';

class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.ticks});
  final Stream<int> ticks;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  final _name = TextEditingController();
  late final AnimationController _anim; // LINT
  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _sub = widget.ticks.listen((_) {});
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _anim, child: TextField(controller: _name));
}

class Clock extends StatefulWidget {
  const Clock({super.key});

  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  final _scroll = ScrollController(); // LINT
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) => ListView(controller: _scroll, children: const [Text('now')]);
}

class Maybe extends StatefulWidget {
  const Maybe({super.key, required this.animate});
  final bool animate;

  @override
  State<Maybe> createState() => _MaybeState();
}

class _MaybeState extends State<Maybe> with SingleTickerProviderStateMixin {
  // Suggest only: set only when animate is true, so disposing it blindly could throw.
  late final AnimationController _anim; // LINT

  @override
  void initState() {
    super.initState();
    if (widget.animate) _anim = AnimationController(vsync: this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

// Must not change.
class Borrowed extends StatefulWidget {
  const Borrowed({super.key, required this.controller});
  final ScrollController controller;

  @override
  State<Borrowed> createState() => _BorrowedState();
}

class _BorrowedState extends State<Borrowed> {
  // Owned by the parent: disposing it here would be a bug.
  late final ScrollController _scroll = widget.controller;
  final _focus = FocusNode();
  final _page = PageController();
  final _search = TextEditingController();

  void _release() => _focus.dispose();

  @override
  void dispose() {
    _release();
    _page
      ..removeListener(_onPage)
      ..dispose();
    _closeAll([_search]);
    super.dispose();
  }

  void _onPage() {}

  void _closeAll(List<TextEditingController> all) {
    for (final c in all) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(controller: _scroll, children: [TextField(focusNode: _focus)]);
}

class Picker<T> extends StatefulWidget {
  const Picker({super.key, required this.items});
  final List<T> items;

  @override
  State<Picker<T>> createState() => _PickerState<T>();
}

// Generic State: the field seen from inside is a substituted copy, and it is disposed.
class _PickerState<T> extends State<Picker<T>> {
  late final ValueNotifier<List<T>> _data = ValueNotifier(widget.items);

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(valueListenable: _data, builder: (_, _, _) => const SizedBox());
}
