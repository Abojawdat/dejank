<p align="center">
  <img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/logo.svg" width="140" alt="dejank icon — a janky frame-time line that turns smooth">
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
  <a href="https://abojawdat.github.io/dejank/"><img alt="live demo" src="https://img.shields.io/badge/live%20demo-try%20it%20in%20the%20browser-F97316"></a>
  <a href="https://github.com/Abojawdat/dejank/actions/workflows/ci.yml"><img alt="tests" src="https://img.shields.io/github/actions/workflow/status/Abojawdat/dejank/ci.yml?branch=main&label=tests"></a>
  <img alt="performance only" src="https://img.shields.io/badge/rules-performance%20only-22C55E">
  <a href="LICENSE"><img alt="PolyForm Shield 1.0.0" src="https://img.shields.io/badge/licence-PolyForm%20Shield-blue"></a>
  <a href="https://github.com/Abojawdat"><img alt="by Abojawdat" src="https://img.shields.io/badge/by-Abojawdat-C8102E"></a>
</p>

## Two packages, one job

dejank comes as **two packages**, so install both: **dejank** with Dart (the tool, on your computer) and
**dejank_meter** with Flutter (inside your app). dejank alone finds and fixes slow code; with dejank_meter you also get
real before/after numbers that prove the fix worked.

```sh
dart pub global activate dejank      # 1. the tool: with Dart, on your computer
flutter pub add dev:dejank_meter     # 2. the meter: with Flutter, inside your app (dev only)
```

| | [**dejank**](https://pub.dev/packages/dejank): the mechanic | [**dejank_meter**](https://pub.dev/packages/dejank_meter): the speed sensor |
|---|---|---|
| What it does | **Finds** slow code and **fixes** it | **Measures** how much faster the app got |
| Where it lives | On your computer (a command-line tool, like `git`) | Inside your app, as a dev dependency. It never ships to users |
| Do you need it? | Yes | Only for the before/after numbers |
| Install | `dart pub global activate dejank` | `flutter pub add dev:dejank_meter` |

<p align="center">
  <img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/session.webp" width="760" alt="Terminal recording: dejank scan finds 7 problems, dejank fix fixes 4 of them, and dejank measure shows 93% fewer widget builds and 84% fewer slow frames">
</p>

<p align="center"><em>Real output, recorded on the demo shop app and an Android phone. <code>dejank fix</code> changed 4 lines.</em></p>

<p align="center">
  <a href="https://abojawdat.github.io/dejank/"><strong>▶ Try the live demo</strong></a>: run <code>dejank scan</code>, <code>fix</code> and <code>measure</code> in your browser
</p>

---

## How to use it

### 1. Install the tool (once, on your computer)

```sh
dart pub global activate dejank
```

### 2. Find slow code

```sh
cd my_app
flutter pub get
dejank scan
```

Every problem, with its file and line, how much it hurts, and whether dejank can fix it:

<img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/scan.png" width="760" alt="dejank scan output: 7 numbered findings, each with its rule, impact and whether it is an auto-fix or a suggestion">

### 3. Fix it

Commit first (git is your undo), then:

```sh
dejank fix --dry-run   # see the diff, change nothing
dejank fix
```

dejank rewrites the safe ones and shows the diff. **Most people stop here, and that's fine: the app is already faster.**

<img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/fix.png" width="760" alt="dejank fix output: the diff of the 4 fixes in 2 files">

### 4. Optional: prove it with numbers

This is where **dejank_meter** comes in. There is no test to write:

```sh
flutter pub add dev:dejank_meter     # once per app
dejank measure -d <phone>            # the name from `flutter devices`
```

Your app opens on the phone with the meter on, and dejank tells you what to do:

```
 ✅ Your app is open on the phone, with the meter on.
    1. Go to the screen you want to check.
    2. Do what feels slow: scroll the list, search, open the keyboard.
    3. Come back here and press Enter.
```

When you press Enter, dejank shows how many times each widget rebuilt and how many frames were slow. Change your code
(for example with `dejank fix`), run `dejank measure -d <phone>` again, do the same steps, and you get the
before/after table:

<img src="https://raw.githubusercontent.com/Abojawdat/dejank/main/art/measure.png" width="760" alt="dejank measure output: widget builds 214,669 to 15,219 (-93%), slow frames 44 to 7 (-84%)">

**Behind the scenes:** dejank starts your app through a tiny launcher it writes in `.dejank/` (never in your code),
dejank_meter counts rebuilds and frame times inside the app while you use it, and dejank shows the table. The app runs
exactly as it does with `flutter run`, so it talks to the same server and asks for the same login. Apps with flavors or
another main file: add `--flavor <name>` or `--target lib/main_dev.dart`.

The numbers are saved in `.dejank/`, which dejank keeps out of git. Each run compares with the last one; run once with
`--baseline` to keep comparing with that run instead. Widget build counts are exact. Frame times need a real device,
and since the build counter only works in debug mode, compare them with each other, not with release builds.

#### Exact, repeatable numbers (for CI)

Using the app by hand is never exactly the same twice. For numbers you can compare to the decimal, or check in CI,
put the steps in an integration test and wrap them in `measure(...)`:

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
flutter pub add dev:dejank_meter 'dev:integration_test:{"sdk":"flutter"}'
dejank measure integration_test/search_test.dart -d <phone>
```

## Why dejank

- **It fixes, not just flags.** About half the rules rewrite the code for you; the rest show the exact fix.
- **It proves it.** Real before/after numbers from a real phone, not a guess.
- **No noise.** Only performance, only rules that matter. A wrong warning is treated as a bug.
- **Safe fixes.** dejank reads your code the way the compiler does, so it only touches Flutter's real classes. Before writing a single file it re-checks the fixed code and skips any fix that would add an error.

## The rules

| Rule | What it finds | Fix |
|---|---|---|
| `mediaquery-of` | `MediaQuery.of(context).size` rebuilds on **every** MediaQuery change, like each frame of the keyboard animation | **auto** → `MediaQuery.sizeOf(context)` (and `paddingOf`, `widthOf`, …), also when it was saved in a variable first |
| `opacity-animation` | `AnimatedBuilder` + `Opacity(opacity: c.value)` rebuilds on every animation frame | **auto** → `FadeTransition(opacity: c)` |
| `image-cache-size` | `Image.network` in a list decodes every image at full size | **auto** → `cacheWidth` from the width × device pixel ratio |
| `shrinkwrap-in-column` | `ListView.builder(shrinkWrap: true)` in a `Column` builds every item at once | suggest → `Expanded` or slivers |
| `intrinsic-in-list` | nested intrinsics in list items (4× layout); a single `IntrinsicHeight` is low impact | suggest |
| `serial-awaits-main` | several independent `await`s before `runApp` delay the first frame | suggest → start them together |
| `hot-allocation` | `DateFormat`, `NumberFormat`, `RegExp` or `TextPainter` created for every list item or on every frame | **auto** for constant `RegExp` → `static final`; suggest otherwise |
| `future-in-build` | `FutureBuilder(future: load())` / `StreamBuilder(stream: watch())`: a new Future or Stream on every build, so it starts over | suggest → create it once in `initState` |
| `controller-in-build` | `TextEditingController()`, `ScrollController()`, `FocusNode()`, `GlobalKey()`… created in `build`: state lost on every rebuild, never disposed | suggest → create once, dispose |
| `missing-dispose` | a `State` creates an `AnimationController`, `TextEditingController`, `ScrollController`, `FocusNode`, `ValueNotifier`, `StreamSubscription` or `Timer` and never disposes or cancels it | **auto** → adds the line (and `dispose()` if missing) |
| `builder-child` | `AnimatedBuilder` / `TweenAnimationBuilder` / `ValueListenableBuilder` rebuilds a subtree that never reads the animation | **auto** → moves it into `child:` |
| `bloc-select` | a `BlocBuilder` that reads one or a few fields of `state`, or `context.watch<X>().field`: rebuilds on every state change | **auto** → `BlocSelector`, `buildWhen` or `context.select` (simple values only); suggest otherwise |
| `eager-list` | `ListView(children: items.map(...))`, or a `Column` in a scroll view built from data: every item built up front | **auto** for `ListView` → `ListView.builder`; suggest otherwise |

### How often code runs

dejank works out how often every function, method and closure runs: on every frame (`AnimatedBuilder`, `CustomPainter.paint`, scroll and animation listeners, drag gestures), for every list item, on every keystroke, on every build, on events, at startup, or only once in a while (button handlers). It follows calls, tear-offs and widget creation across files, so a finding shows the path that makes it hot:

```
Creates a new NumberFormat for every list item: TripList.build → itemBuilder → TripTile.build → TripTile._price.
```

A button handler is never treated as hot, so a `DateFormat` in `onTap:` is left alone.

With no path, dejank checks `lib/`. To skip generated or copied-in code, list it under `analyzer: exclude:` in your `analysis_options.yaml`; dejank follows it.

In CI or a pre-commit hook, `dejank scan` exits with code 1 when it finds a high-impact problem (`--fail-on=any` or `--fail-on=never` to change that). To keep something on purpose, put `// dejank:ignore <rule>` on that line or the line above. In a terminal the output has colors, numbers and emojis; piped into a file or a CI log it stays plain text. `NO_COLOR=1` turns the colors off, `FORCE_COLOR=1` turns them on (for example in GitHub Actions).

Adding `const` isn't here on purpose: turn on the official `prefer_const_constructors` lint and run `dart fix --apply`.

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

هو حزمتان تعملان معًا:

- **dejank** هو الميكانيكي: أداة على جهازك تجد الكود البطيء وتصلحه.
- **dejank_meter** هو حسّاس السرعة: يُضاف داخل تطبيقك في الاختبارات فقط (لا يصل إلى المستخدمين)، ويقيس كم أصبح التطبيق أسرع. تحتاجه فقط إذا أردت أرقام قبل وبعد.

```sh
# ١. ثبّت الأداة مرة واحدة على جهازك
dart pub global activate dejank

# ٢. ابحث عن الكود البطيء
cd my_app && flutter pub get
dejank scan

# ٣. أصلحه (معظم الناس يكتفون بهذا)
dejank fix

# ٤. اختياري: أثبت التحسّن بالأرقام (هنا يأتي dejank_meter)، بدون كتابة أي اختبار
flutter pub add dev:dejank_meter
dejank measure -d <phone>   # يفتح تطبيقك على الهاتف: استخدمه ثم اضغط Enter
dejank fix
dejank measure -d <phone>   # نفس الخطوات مرة ثانية: جدول قبل وبعد
```

في تطبيق المتجر التجريبي على هاتف Android: غيّر `dejank fix` أربعة أسطر فقط، فانخفض عدد مرات بناء الـ widgets بنسبة **٩٣٪** وانخفضت الإطارات البطيئة بنسبة **٨٤٪**.

</div>

---

## Author

Built by **Mohammad Othman (Abojawdat)** — [github.com/Abojawdat](https://github.com/Abojawdat). If it made your app smoother, a ⭐ is appreciated.

## Licence

[PolyForm Shield 1.0.0](LICENSE). Free to use on any app, including at work, and you may change it for your own use.
You may not publish a copy, renamed or not, as a competing tool, free or paid.
