import 'package:flutter/material.dart';

enum Status { open, closed }

const kMenu = ['home', 'orders', 'settings'];

class Orders extends StatelessWidget {
  const Orders({super.key, required this.orders, required this.chips, required this.extra});
  final List<String> orders;
  final List<String> chips;
  final List<Widget> extra;

  static const _bubbles = [1, 2, 3];

  @override
  Widget build(BuildContext context) {
    final items = ['a', 'b'];
    return Column(
      children: [
        Expanded(child: ListView.builder(itemCount: orders.length, itemBuilder: (_, i) => ListTile(title: Text(orders[i])))), // LINT
        Expanded(
          child: ListView.builder( // LINT
            padding: const EdgeInsets.all(8),
            itemCount: orders.length, itemBuilder: (_, i) => Text(orders[i]),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column( // LINT
              children: [for (final o in orders) ListTile(title: Text(o))],
            ),
          ),
        ),
        Expanded(child: GridView.count(crossAxisCount: 2, children: [for (final o in orders) Text(o)])), // LINT

        // Must not change.
        // A few items.
        Expanded(child: ListView(children: [for (final c in chips.take(3)) Chip(label: Text(c))])),
        Expanded(child: ListView(children: [for (final s in Status.values) Text(s.name)])),
        Expanded(child: ListView(children: List.generate(5, (i) => Text('$i')))),
        // Doesn't scroll.
        Row(children: [for (final c in chips) Text(c)]),
        Column(children: [for (final c in chips) Text(c)]),
        // Fixed lists defined elsewhere.
        Expanded(child: ListView(children: [for (final m in kMenu) Text(m)])),
        Expanded(child: ListView(children: [for (final b in _bubbles) Text('$b')])),
        Expanded(child: ListView(children: items.map((i) => Text(i)).toList())),
        Expanded(child: ListView(children: [for (final (i, m) in ['a', 'b'].indexed) Text('$i $m')])),
        // Widgets the caller already built.
        Expanded(child: ListView(children: [for (final w in extra) Padding(padding: EdgeInsets.zero, child: w)])),
        // Already lazy.
        Expanded(child: ListView.builder(itemCount: orders.length, itemBuilder: (_, i) => Text(orders[i]))),
      ],
    );
  }
}
