# How to use dejank

dejank is **two packages** that work together:

- **[dejank](https://pub.dev/packages/dejank)** is the mechanic: a command-line tool on your computer that finds slow
  Flutter code and fixes it.
- **[dejank_meter](https://pub.dev/packages/dejank_meter)** is the speed sensor: you add it to your app, only for
  tests (it never ships to users), and it measures how much faster the app got. You need it only for the
  before/after numbers.

## 1. Install the tool (once, on your computer)

```sh
dart pub global activate dejank
```

## 2. Find slow code

```sh
cd my_app
flutter pub get
dejank scan
```

Every problem, with its file and line, how much it hurts, and whether dejank can fix it.

## 3. Fix it

Commit first (git is your undo), then:

```sh
dejank fix --dry-run   # see the diff, change nothing
dejank fix
```

Most people stop here: the app is already faster.

## 4. Optional: prove it with numbers

**a)** Add the meter to your app as a **dev** dependency:

```sh
flutter pub add dev:dejank_meter 'dev:integration_test:{"sdk":"flutter"}'
```

**b)** In `integration_test/search_test.dart`, wrap the steps you care about in `measure(...)`:

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

**c)** Measure before the fix, fix, then measure again:

```sh
dejank measure integration_test/search_test.dart -d <phone>
dejank fix
dejank measure integration_test/search_test.dart -d <phone>
```

The second run prints a before/after table, like this one from the demo app on an Android phone:

```
search                          before       now
widget builds                  214,669    15,219  -93%
  ProductTile                    4,640       260  -94%
frames                             140       142  +1%
  avg build                    27.1 ms    8.9 ms  -67%
  slow frames                       44         7  -84%
```

`dejank measure` runs your test, `dejank_meter` counts rebuilds and frame times inside the app while it runs, and
`dejank` reads those counts and shows the table.

## Try it on the demo app

[`slow_app`](https://github.com/Abojawdat/dejank/tree/main/example/slow_app) is a 200-product shop that triggers every
rule, with the measure test already written:

```sh
git clone https://github.com/Abojawdat/dejank
cd dejank/example/slow_app
flutter pub get
dejank scan
dejank measure integration_test/search_test.dart -d <phone>
dejank fix
dejank measure integration_test/search_test.dart -d <phone>
```

Or try it in your browser: https://abojawdat.github.io/dejank/
