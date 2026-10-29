import 'package:dejank_meter/dejank_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:slow_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search', (tester) async {
    final products = Product.listFromJson(
      await rootBundle.loadString('assets/catalog.json'),
    );
    Future<void> frames(int count) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> keyboard({required bool open}) async {
      for (var i = 1; i <= 20; i++) {
        final step = open ? i : 20 - i;
        tester.view.viewInsets = FakeViewPadding(
          bottom: step * 15 * tester.view.devicePixelRatio,
        );
        await frames(1);
      }
    }

    await measure('search', () async {
      await tester.pumpWidget(ShopApp(products: products));
      await frames(30);
      await keyboard(open: true);
      await tester.enterText(find.byKey(const Key('search')), 'back');
      await frames(10);
      await keyboard(open: false);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1500),
      );
      await frames(60);
    });
    tester.view.resetViewInsets();
  });
}
