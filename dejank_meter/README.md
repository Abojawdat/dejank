<p align="center">
  <img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/icon.svg" width="110" alt="dejank icon — a janky frame-time line that turns smooth">
</p>

<h1 align="center">dejank_meter</h1>

<p align="center">
  <strong>Counts widget rebuilds and frame times while a test runs.</strong><br>
  The measuring half of <a href="https://pub.dev/packages/dejank">dejank</a>: run a test, fix your code, run it again, see the difference.
</p>

<p align="center">
  Built by <a href="https://github.com/Abojawdat"><strong>Mohammad Othman (Abojawdat)</strong></a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/dejank_meter"><img alt="pub" src="https://img.shields.io/pub/v/dejank_meter.svg"></a>
  <img alt="zero dependencies" src="https://img.shields.io/badge/dependencies-zero-2ea44f">
  <a href="LICENSE"><img alt="PolyForm Shield 1.0.0" src="https://img.shields.io/badge/licence-PolyForm%20Shield-blue"></a>
  <a href="https://github.com/Abojawdat"><img alt="by Abojawdat" src="https://img.shields.io/badge/by-Abojawdat-C8102E"></a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/measure.png" width="760" alt="dejank measure before and after: widget builds down 93%, slow frames down 84%">
</p>

---

## Use

```sh
flutter pub add dev:dejank_meter 'dev:integration_test:{"sdk":"flutter"}'
dart pub global activate dejank
```

Wrap the steps you care about in `measure`:

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
dejank measure integration_test/search_test.dart -d <device>
```

The first run saves the numbers. Change your code (for example with `dejank fix`) and run again to get the before/now table.

## What it counts

- **Widget builds**, per widget type, through Flutter's `debugOnRebuildDirtyWidget` hook. Exact, but only in debug mode, which is how integration tests run.
- **Frames**: count, average build and raster time, and how many missed the 60 fps budget. Needs a real device. Because it runs in debug mode, compare runs with each other, not with release builds.

It only runs inside `measure` and puts the hooks back when it is done. It is a dev dependency, so it never ships inside your app.

## Licence

[PolyForm Shield 1.0.0](LICENSE): free to use, including at work; no competing copies. Built by **Mohammad Othman (Abojawdat)** — [github.com/Abojawdat](https://github.com/Abojawdat).
