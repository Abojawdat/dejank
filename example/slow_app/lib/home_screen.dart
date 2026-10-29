import 'package:flutter/material.dart';

import 'main.dart';
import 'product_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.products});
  final List<Product> products;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final p in widget.products)
        if (p.name.toLowerCase().contains(_query)) p,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Turbo Shop')),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Column(
          children: [
            const SaleBanner(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                key: const Key('search'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search products',
                ),
                onChanged: (q) => setState(() => _query = q.toLowerCase()),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              itemBuilder: (context, i) => ProductTile(product: visible[i]),
            ),
          ],
        ),
      ),
    );
  }
}

class SaleBanner extends StatefulWidget {
  const SaleBanner({super.key});

  @override
  State<SaleBanner> createState() => _SaleBannerState();
}

class _SaleBannerState extends State<SaleBanner>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    lowerBound: 0.4,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Opacity(opacity: _pulse.value, child: child),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.deepOrange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Summer sale: 30% off everything',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
