import 'package:flutter/material.dart';

class Sample extends StatelessWidget {
  const Sample({super.key, required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder( // LINT
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (_, i) => Text(items[i]),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: ListView.separated( // LINT
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (_, i) => Text(items[i]),
            separatorBuilder: (_, _) => const Divider(),
          ),
        ),
        SizedBox(
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (items.isNotEmpty)
                  GridView.builder( // LINT
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
                    itemCount: items.length,
                    itemBuilder: (_, i) => Text(items[i]),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            // A list inside each item of another list.
            itemBuilder: (_, i) => ListView.builder( // LINT
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (_, j) => Text(items[j]),
            ),
          ),
        ),

        // Must not change.
        // Expanded limits the height, so only visible items are built.
        Expanded(
          child: ListView.builder(shrinkWrap: true, itemCount: items.length, itemBuilder: (_, i) => Text(items[i])),
        ),
        // A children list: small, and its items exist anyway.
        ListView(shrinkWrap: true, children: const [Text('a'), Text('b')]),
        // Small fixed count.
        ListView.builder(shrinkWrap: true, itemCount: 3, itemBuilder: (_, i) => Text('$i')),
        // Horizontal: the Column limits its width.
        ListView.builder(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: items.length,
          itemBuilder: (_, i) => Text(items[i]),
        ),
        // Not shrinkWrap.
        Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (_, i) => Text(items[i]))),
        // Unknown parent (a dialog sizes it): not flagged.
        Dialog(
          child: ListView.builder(shrinkWrap: true, itemCount: items.length, itemBuilder: (_, i) => Text(items[i])),
        ),
      ],
    );
  }
}
