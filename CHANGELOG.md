## 0.1.4

- README, demo page and `dejank measure --help` now say where `dejank_meter` comes from and how to add it.

## 0.1.3

- **Heat map:** dejank now knows how often code runs (every frame, every list item, every keystroke, every build, events, startup, rare) by following calls, tear-offs and widget creation across files. Findings show the path, like `TripList.build → itemBuilder → TripTile.build → TripTile._price`.
- New rule `hot-allocation`: `DateFormat`, `NumberFormat`, `RegExp` or `TextPainter` created for every list item or every frame. Constant `RegExp`s are moved to a `static final` automatically.
- New rule `future-in-build`: `FutureBuilder` / `StreamBuilder` given a Future or Stream created in `build`, so it starts over on every rebuild.
- New rule `controller-in-build`: controllers, `FocusNode`s and `GlobalKey`s created in `build`.
- New rule `missing-dispose`: controllers, notifiers, subscriptions and timers a `State` creates but never disposes or cancels. Only objects the State creates itself (not ones handed in through `widget`). Auto-fix adds the line, or the whole `dispose()`.
- New rule `builder-child`: an `AnimatedBuilder` / `TweenAnimationBuilder` / `ValueListenableBuilder` that rebuilds a subtree which never reads the value. Auto-fix moves it into `child:`; only subtrees proven independent (no animation, no app methods, no fields that can change) are moved.
- New rule `bloc-select`: a `BlocBuilder` without `buildWhen` that reads only one to three fields of `state` becomes a `BlocSelector` (one field) or gets a `buildWhen` (two or three); `context.watch<X>().a.b` becomes `context.select`. Automatic only for simple values (numbers, text, bools, enums, dates) and when the builder doesn't read the bloc another way.
- `mediaquery-of` also fixes `final mq = MediaQuery.of(context)` when only fields like `mq.size` and `mq.padding` are read.
- New rule `eager-list`: lists built all at once from data. `ListView(children: ...)` is auto-fixed to `ListView.builder`; a `Column` in a scroll view gets a suggestion. Short lists (`.take(3)`, enum values, literals) are left alone.
- No more wrong warnings for one-off widgets in lists: only code that repeats (`itemBuilder:`, builder delegates, or `for` / `.map()` / `List.generate` in `children:`) counts as a list item. A search bar or an avatar in a fixed `children:` list is no longer flagged.
- `intrinsic-in-list`: nested intrinsics are high impact; a single `IntrinsicHeight` is low with honest advice (keep it when the height depends on the content); `IntrinsicWidth` alone is not flagged (chat bubbles need it).
- `image-cache-size`: suggestions compile when the width is nullable, and `BoxFit.cover` gets advice that fits it.
- `serial-awaits-main`: low impact, warns that `.wait` wraps errors in `ParallelWaitError`, and indents multi-line calls properly.
- `// dejank:ignore <rule>` on the line or the line above silences a finding.
- `dejank scan` exits with code 1 only for high-impact findings; `--fail-on=high|any|never` to choose.
- `opacity-animation` is medium impact with a correct message: Opacity does not repaint its child, the saving is the rebuild on every frame.
- `mediaquery-of` on `viewInsets` is low impact and says why (the keyboard changes viewInsets on every frame).
- List items are also found in `PageView`, `AnimatedList`, `ReorderableListView` and any widget with an `itemBuilder:` (like `PagedListView` or `MasonryGridView`).
- `dejank measure --baseline` keeps a fixed "before" to compare against.
- `dejank fix` warns when the files it changes have uncommitted edits.
- `dejank fix` no longer counts overlapping fixes it could not apply, and re-formats changed files that were `dart format`-clean before.

## 0.1.2

- `dejank scan` shows how many findings are high and medium impact.
- `dejank fix` shows what it fixed per rule, and the last `dejank measure` numbers so you can measure again and see how much faster it is.

## 0.1.1

- `shrinkwrap-in-column` now finds lists returned from `if` / `switch` and from state-management builders (`BlocBuilder`, Provider's `Consumer`, Riverpod, GetX, MobX), the usual BLoC screen shape. It no longer suggests `Expanded` for a `Column` inside a scroll view.
- List rules no longer flag a screen that a list item opens on tap through a helper method (a wrong warning).
- Colors, numbered findings, emojis and a summary in the terminal (plain text when piped; `NO_COLOR` / `FORCE_COLOR` respected).
- `dejank scan` exits with code 1 when it finds problems, for CI and pre-commit hooks.
- `dejank fix --dry-run` shows the diff without writing anything.
- With no path, `scan` and `fix` check `lib/`.
- `dejank measure` keeps `.dejank/` out of git by itself.
- "1 problem", not "1 problems".
- New README images, pub.dev screenshots, and a live demo page: https://abojawdat.github.io/dejank/

## 0.1.0

First release.

- `dejank scan`: lists slow code with file:line, impact, and whether it can be fixed automatically.
- `dejank fix`: applies the safe fixes, shows a diff, and refuses any fix that would add an analyzer error.
- `dejank measure`: runs a test that uses `dejank_meter`, saves the numbers, and compares them with the last run.
- Six rules: `mediaquery-of`, `opacity-animation`, `image-cache-size` (auto), `shrinkwrap-in-column`, `intrinsic-in-list`, `serial-awaits-main` (suggest).
