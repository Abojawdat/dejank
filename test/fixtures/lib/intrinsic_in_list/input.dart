import 'package:flutter/material.dart';

class Screen extends StatelessWidget {
  const Screen({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Not in a list: built once.
        const IntrinsicHeight(child: Row(children: [Text('header')])),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => IntrinsicHeight( // LINT
              child: Row(children: [Text(items[i]), const VerticalDivider()]),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(itemCount: items.length, itemBuilder: (_, i) => ItemTile(title: items[i])),
        ),
        Expanded(child: ListView(children: [for (final item in items) _row(item)])),
        Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: _tearOff)),
      ],
    );
  }

  Widget _row(String item) => IntrinsicWidth(child: Text(item)); // LINT

  Widget _tearOff(BuildContext context, int i) => IntrinsicHeight(child: Text(items[i])); // LINT

  // Not used by any list.
  Widget unused() => const IntrinsicHeight(child: Text('x'));
}

/// Used inside a list by another class.
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: IntrinsicHeight(child: Text(title)), // LINT
      trailing: const ItemBadge(),
      // Opened on tap: Details is not part of the list.
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Details())),
    );
  }
}

/// Used by ItemTile, so it is in the list too.
class ItemBadge extends StatelessWidget {
  const ItemBadge({super.key});

  @override
  Widget build(BuildContext context) => const IntrinsicWidth(child: Text('new')); // LINT
}

class Details extends StatelessWidget {
  const Details({super.key});

  @override
  Widget build(BuildContext context) => const IntrinsicHeight(child: Text('details'));
}
