# dejank_meter example

dejank_meter is the measuring half of [dejank](https://pub.dev/packages/dejank). dejank finds and fixes slow Flutter
code; this package measures how much faster the app got, so `dejank measure` can show before/after numbers.

## 1. Install both

```sh
dart pub global activate dejank      # the tool, on your computer
flutter pub add dev:dejank_meter     # the meter, in your app (dev only)
```

## 2. Measure while you use your app

No test to write:

```sh
dejank measure -d <phone>
```

Your app opens on the phone with the meter on. Go to the screen you want to check, do what feels slow (scroll, search,
open the keyboard), then press Enter on the computer.

## 3. Change your code and measure again

```sh
dejank fix
dejank measure -d <phone>
```

Do the same steps, and dejank prints the before/after table:

```
search                          before       now
widget builds                  214,669    15,219  -93%
  ProductTile                    4,640       260  -94%
frames                             140       142  +1%
  avg build                    27.1 ms    8.9 ms  -67%
  slow frames                       44         7  -84%
```

Real numbers from the dejank demo app on an Android phone.

## Exact, repeatable numbers (for CI)

Put the steps in an integration test and wrap them in `measure(...)`:

```dart
import 'package:dejank_meter/dejank_meter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('search', (tester) async {
    await measure('search', () async {
      await tester.pumpWidget(const MyApp());
      await tester.enterText(find.byType(TextField), 'shoes');
      await tester.pumpAndSettle();
    });
  });
}
```

```sh
dejank measure integration_test/search_test.dart -d <phone>
```

A full working example is in the dejank repo:
[`example/slow_app/integration_test/search_test.dart`](https://github.com/Abojawdat/dejank/blob/main/example/slow_app/integration_test/search_test.dart).
