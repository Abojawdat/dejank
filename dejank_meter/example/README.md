# dejank_meter example

dejank_meter is the measuring half of [dejank](https://pub.dev/packages/dejank). dejank finds and fixes slow Flutter
code; this package measures how much faster the app got, so `dejank measure` can show before/after numbers.

## 1. Install both

```sh
dart pub global activate dejank                                             # the tool, on your computer
flutter pub add dev:dejank_meter 'dev:integration_test:{"sdk":"flutter"}'   # the meter, in your app (dev only)
```

Add it as a **dev** dependency: it is only used in tests and never ships to users.

## 2. Write a measure test

`integration_test/search_test.dart`:

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

Everything inside `measure('search', ...)` is counted: widget rebuilds per widget, and frame build and raster times.

## 3. Measure, fix, measure again

```sh
dejank measure integration_test/search_test.dart -d <phone>
dejank fix
dejank measure integration_test/search_test.dart -d <phone>
```

```
search                          before       now
widget builds                  214,669    15,219  -93%
  ProductTile                    4,640       260  -94%
frames                             140       142  +1%
  avg build                    27.1 ms    8.9 ms  -67%
  slow frames                       44         7  -84%
```

Real numbers from the dejank demo app on an Android phone. A full working example is in the dejank repo:
[`example/slow_app/integration_test/search_test.dart`](https://github.com/Abojawdat/dejank/blob/main/example/slow_app/integration_test/search_test.dart).
