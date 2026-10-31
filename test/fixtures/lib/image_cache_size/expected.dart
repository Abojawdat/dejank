import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;

const url = 'https://example.com/a.png';

class Sample extends StatelessWidget {
  const Sample({super.key, required this.size, this.maybe});
  final double size;
  final double? maybe;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (ctx, i) => Image.network(url, width: 100, cacheWidth: (100 * MediaQuery.devicePixelRatioOf(ctx)).round()), // LINT
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Image.network( // LINT
                  url,
                  width: 80.5,
                  cacheWidth: (80.5 * MediaQuery.devicePixelRatioOf(context)).round(),
                  height: 60,
                  fit: BoxFit.contain,
                ),
                m.Image.network(url, width: 50, cacheWidth: (50 * m.MediaQuery.devicePixelRatioOf(context)).round()), // LINT
                // Suggest only: with cover the photo's shape decides the drawn size.
                Image.network(url, width: 100, height: 100, fit: BoxFit.cover), // LINT
                // Suggest only: width is a variable (could be infinity).
                Image.network(url, width: size), // LINT
                // Suggest only: width can be null.
                Image.network(url, width: maybe), // LINT
              ],
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            children: [
              for (var i = 0; i < 4; i++) Image.network(url, width: 120, cacheWidth: (120 * MediaQuery.devicePixelRatioOf(context)).round()), // LINT
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemBuilder: (_, i) => Image.network(url, width: 40, cacheWidth: (40 * MediaQuery.devicePixelRatioOf(context)).round()), // LINT
          ),
        ),

        // Must not change.
        Image.network(url, width: 100), // not in a list
        Expanded(
          child: ListView(
            children: [
              Image.network(url, width: 100), // one image in a fixed list: built once, not per item
              Image.network(url, width: 100, cacheWidth: 300), // already has cacheWidth
              for (var i = 0; i < 3; i++) Image.network(url), // no width: the layout decides
            ],
          ),
        ),
      ],
    );
  }
}

class StatefulSample extends StatefulWidget {
  const StatefulSample({super.key});

  @override
  State<StatefulSample> createState() => _StatefulSampleState();
}

class _StatefulSampleState extends State<StatefulSample> {
  Widget _list() => ListView.builder(itemBuilder: (_, i) => Image.network(url, width: 64, cacheWidth: (64 * MediaQuery.devicePixelRatioOf(context)).round())); // LINT

  @override
  Widget build(BuildContext context) => _list();
}

// Suggest only: no BuildContext here.
Widget gallery() => ListView.builder(itemBuilder: (_, i) => Image.network(url, width: 30)); // LINT
