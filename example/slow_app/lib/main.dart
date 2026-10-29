import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final catalog = await rootBundle.loadString('assets/catalog.json');
  runApp(ShopApp(products: Product.listFromJson(catalog)));
}

class ShopApp extends StatelessWidget {
  const ShopApp({super.key, required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turbo Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
      home: HomeScreen(products: products),
    );
  }
}

class Product {
  const Product({required this.id, required this.name, required this.price});
  final int id;
  final String name;
  final double price;

  String get imageUrl => 'https://picsum.photos/seed/turbo$id/800/800';

  static List<Product> listFromJson(String json) => [
    for (final p in jsonDecode(json) as List)
      Product(
        id: p['id'] as int,
        name: p['name'] as String,
        price: (p['price'] as num).toDouble(),
      ),
  ];
}
