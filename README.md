<p align="center">
  <img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/icon.svg" width="140" alt="dejank icon — a janky frame-time line that turns smooth">
</p>

<h1 align="center">dejank</h1>

<p align="center">
  <strong>Finds slow Flutter code, fixes it for you, and proves it with numbers.</strong><br>
  Like the React Compiler, for Flutter: a few high-impact performance rules,<br>
  every one with an automatic fix or the exact fix shown, and before/after rebuild counts to prove it worked.
</p>

<p align="center">
  Built by <a href="https://github.com/Abojawdat"><strong>Mohammad Othman (Abojawdat)</strong></a>
</p>

<p align="center">
  <a href="https://pub.dev/packages/dejank"><img alt="dejank on pub" src="https://img.shields.io/pub/v/dejank.svg?label=dejank"></a>
  <a href="https://pub.dev/packages/dejank_meter"><img alt="dejank_meter on pub" src="https://img.shields.io/pub/v/dejank_meter.svg?label=dejank_meter"></a>
  <a href="https://github.com/Abojawdat/dejank/actions/workflows/ci.yml"><img alt="tests" src="https://img.shields.io/github/actions/workflow/status/Abojawdat/dejank/ci.yml?branch=main&label=tests"></a>
  <img alt="performance only" src="https://img.shields.io/badge/rules-performance%20only-22C55E">
  <a href="LICENSE"><img alt="PolyForm Shield 1.0.0" src="https://img.shields.io/badge/licence-PolyForm%20Shield-blue"></a>
  <a href="https://github.com/Abojawdat"><img alt="by Abojawdat" src="https://img.shields.io/badge/by-Abojawdat-C8102E"></a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/banner.svg" width="760" alt="Terminal: dejank fix fixed 4 problems, then dejank measure shows widget builds down 93% and slow frames down 86%">
</p>

<p align="center"><em>Real output: the demo shop app on an Android phone. <code>dejank fix</code> changed 4 lines.</em></p>

---

## What you get

- **`dejank scan`** lists slow code with `file:line`, how much it hurts, and whether it can be fixed automatically.
- **`dejank fix`** rewrites the safe ones and shows you the diff.
- **`dejank measure`** runs your test, counts widget rebuilds and frame times, and compares them with the last run.
- **No noise.** Only performance, only rules that matter. A wrong warning is treated as a bug.
- **Safe fixes.** dejank reads your code the way the compiler does, so it only touches Flutter's real classes. Before writing a single file it re-checks the fixed code and skips any fix that would add an error.

## Quick start

```sh
dart pub global activate dejank

cd my_app
flutter pub get
dejank scan
```

```
lib/product_tile.dart:11:21  mediaquery-of  high  auto
  Use MediaQuery.widthOf(context): rebuilds only when `width` changes, not on every MediaQuery change (like each frame of the keyboard animation).
lib/product_tile.dart:15:14  intrinsic-in-list  medium  suggest
  IntrinsicHeight lays out its child twice (measure, then real) for every list item.
  Use a fixed height instead: SizedBox(height: 72, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, ...))

7 problems: 4 auto-fixable (run `dejank fix`), 3 need a human.
```

Then commit (git is your undo) and run:

```sh
dejank fix --dry-run   # see the diff, change nothing
dejank fix
```

```
lib/product_tile.dart
  @@ line 11
  -     final compact = MediaQuery.of(context).size.width < 360;
  +     final compact = MediaQuery.widthOf(context) < 360;

Fixed 4 problems in 2 files. 3 need a human, see `dejank scan`.
```

## The rules

| Rule | What it finds | Fix |
|---|---|---|
| `mediaquery-of` | `MediaQuery.of(context).size` rebuilds on **every** MediaQuery change, like each frame of the keyboard animation | **auto** → `MediaQuery.sizeOf(context)` (and `paddingOf`, `widthOf`, …) |
| `opacity-animation` | `AnimatedBuilder` + `Opacity(opacity: c.value)` rebuilds and repaints every frame | **auto** → `FadeTransition(opacity: c)` |
| `image-cache-size` | `Image.network` in a list decodes every image at full size | **auto** → `cacheWidth` from the width × device pixel ratio |
| `shrinkwrap-in-column` | `ListView.builder(shrinkWrap: true)` in a `Column` builds every item at once | suggest → `Expanded` or slivers |
| `intrinsic-in-list` | `IntrinsicHeight` / `IntrinsicWidth` lays out every list item twice | suggest → a fixed size |
| `serial-awaits-main` | several independent `await`s before `runApp` delay the first frame | suggest → start them together |

List rules also follow your tile widgets and helper methods into other files, so they see the code that actually runs inside the list.

With no path, dejank checks `lib/`. To skip generated or copied-in code, list it under `analyzer: exclude:` in your `analysis_options.yaml`; dejank follows it.

In CI or a pre-commit hook, `dejank scan` exits with code 1 when it finds problems. In a terminal the output has colors, numbers and emojis; piped into a file or a CI log it stays plain text. `NO_COLOR=1` turns the colors off, `FORCE_COLOR=1` turns them on (for example in GitHub Actions).

Adding `const` isn't here on purpose: turn on the official `prefer_const_constructors` lint and run `dart fix --apply`.

## Prove it: `dejank measure`

Add the meter to your app's dev dependencies:

```sh
flutter pub add dev:dejank_meter 'dev:integration_test:{"sdk":"flutter"}'
```

Wrap the steps of an integration test in `measure`:

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

Run it, fix, run it again:

```sh
dejank measure integration_test/search_test.dart -d <device>
dejank fix
dejank measure integration_test/search_test.dart -d <device>
```

The numbers are saved in `.dejank/`, which dejank keeps out of git. Widget build counts are exact. Frame times need a real device, and since the build counter only works in debug mode, compare them with each other, not with release builds.

`dejank_meter` is a dev dependency: it never ships inside your app.

## Example app

[`example/slow_app`](example/slow_app) is a 200-product shop that triggers every rule. Its [search test](example/slow_app/integration_test/search_test.dart) opens the keyboard, types, closes it and scrolls. That is the run in the picture at the top.

## Found a bug?

A wrong warning or a fix that breaks your code is a bug. [Open an issue](https://github.com/Abojawdat/dejank/issues) with the code that triggered it, the `dejank` version and `flutter --version`.

## Releasing

Bump `version:` in `pubspec.yaml` (or `dejank_meter/pubspec.yaml`), add a line to the CHANGELOG, push to `main`. The `release` workflow tags it (`v1.2.3` or `dejank_meter-v1.2.3`) and the `publish` workflow sends it to pub.dev.

## More from Abojawdat

| Package | What it is |
|---|---|
| [duo_dynamic_sizing](https://pub.dev/packages/duo_dynamic_sizing) | Adaptive layout for the foldable iPhone Duo and any screen: live hinge angle, posture, split panes |
| [bank_card_3d](https://pub.dev/packages/bank_card_3d) | Visa and Mastercard cards in real 3D, photoreal or glass, with a wallet stack and entry form |
| [iraqi_license_plate](https://pub.dev/packages/iraqi_license_plate) | Photoreal Iraqi vehicle plates with the full governorate and category data model |

---

<div dir="rtl">

## بالعربية

**dejank** يجد الكود البطيء في تطبيق Flutter، ويصلحه لك، ويثبت التحسّن بالأرقام.

```sh
dart pub global activate dejank
cd my_app && flutter pub get
dejank scan   # يعرض المشاكل مع الملف والسطر
dejank fix    # يصلح المشاكل الآمنة ويعرض الفرق
dejank measure integration_test/search_test.dart -d <device>   # الأرقام قبل وبعد
```

في تطبيق المتجر التجريبي على هاتف Android: غيّر `dejank fix` أربعة أسطر فقط، فانخفض عدد مرات بناء الـ widgets بنسبة **٩٣٪** وانخفضت الإطارات البطيئة بنسبة **٨٦٪**.

</div>

---

## Author

Built by **Mohammad Othman (Abojawdat)** — [github.com/Abojawdat](https://github.com/Abojawdat). If it made your app smoother, a ⭐ is appreciated.

## Licence

[PolyForm Shield 1.0.0](LICENSE). Free to use on any app, including at work, and you may change it for your own use.
You may not publish a copy, renamed or not, as a competing tool, free or paid.
