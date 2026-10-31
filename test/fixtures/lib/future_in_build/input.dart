import 'package:flutter/material.dart';

class Orders extends StatefulWidget {
  const Orders({super.key, required this.future});
  final Future<int> future;

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  late final Future<int> _count = load();

  Future<int> load() async => 1;

  Stream<int> watch() => const Stream.empty();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<int>(future: load(), builder: (_, s) => Text('${s.data}')), // LINT
        StreamBuilder<int>(stream: watch().map((x) => x), builder: (_, s) => Text('${s.data}')), // LINT

        // Must not change: the Future is made once and kept.
        FutureBuilder<int>(future: _count, builder: (_, s) => Text('${s.data}')),
        FutureBuilder<int>(future: widget.future, builder: (_, s) => Text('${s.data}')),
        // A dialog opened by a tap: built once per tap.
        ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => FutureBuilder<int>(future: load(), builder: (_, s) => Text('${s.data}')),
          ),
          child: const Text('details'),
        ),
      ],
    );
  }
}
