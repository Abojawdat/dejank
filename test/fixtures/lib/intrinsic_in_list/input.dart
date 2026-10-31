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
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => IntrinsicHeight( // LINT
              child: Row(
                children: [
                  IntrinsicWidth(child: Text(items[i])), // LINT
                  const Text('nested'),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(itemBuilder: (_, i) => IntrinsicHeight(child: Text(items[i]))), // LINT
        ),
        // The app's own (or another package's) list widget with an itemBuilder.
        Expanded(child: MyList(itemBuilder: (_, i) => IntrinsicHeight(child: Text(items[i])))), // LINT
        // Fixed pages, built once each.
        Expanded(child: PageView(children: const [IntrinsicHeight(child: Text('intro'))])),
        // A chat bubble shrinks to its text: IntrinsicWidth alone is not flagged.
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => IntrinsicWidth(child: Column(children: [Text(items[i])])),
          ),
        ),
        // One search bar at the top of a page that scrolls: built once, not per item.
        Expanded(
          child: ListView(
            children: [
              const IntrinsicHeight(child: Row(children: [Text('search')])),
              const SearchBox(),
              for (final item in items) Text(item),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String item) => IntrinsicHeight(child: Text(item)); // LINT

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
      subtitle: _subtitle(),
      trailing: const ItemBadge(),
      // Opened on tap: Details is not part of the list.
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Details())),
      // Opened from a helper the tap calls: MoreDetails is not part of the list either.
      onLongPress: () => _open(context),
    );
  }

  Widget _subtitle() => IntrinsicHeight(child: Text(title)); // LINT

  void _open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MoreDetails()));
}

/// Used by ItemTile, so it is in the list too.
class ItemBadge extends StatelessWidget {
  const ItemBadge({super.key});

  @override
  Widget build(BuildContext context) => const IntrinsicHeight(child: Text('new')); // LINT
}

class Details extends StatelessWidget {
  const Details({super.key});

  @override
  Widget build(BuildContext context) => const IntrinsicHeight(child: Text('details'));
}

class MoreDetails extends StatelessWidget {
  const MoreDetails({super.key});

  @override
  Widget build(BuildContext context) => const IntrinsicHeight(child: Text('more'));
}

/// Used once in a list's fixed children, so it is not a list item.
class SearchBox extends StatelessWidget {
  const SearchBox({super.key});

  @override
  Widget build(BuildContext context) => const IntrinsicHeight(child: Text('search'));
}

class MyList extends StatelessWidget {
  const MyList({super.key, required this.itemBuilder});
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => ListView.builder(itemBuilder: itemBuilder);
}
