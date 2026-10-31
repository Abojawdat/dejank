# The deep engine

Goal (owner, 2026-10-31): a professional dejanker, not a set of one-line pattern checks. Three reviews on real apps
(wasel, merchant, drivers, wassilni) showed the same gap: dejank only sees one line at a time, so it misses most real
jank and cannot rank what it finds.

dejank has to know three things a linter doesn't:

1. **How often code runs** (heat).
2. **What each rebuild reads and what each state change writes** (read/write map).
3. **What really happened on a device**, pointed back to the line (deep measure).

## 1. Heat map (`lib/src/heat.dart`)

Every function, method and closure gets the hottest place it is reachable from:

| Heat | Comes from |
|---|---|
| frame | `AnimatedBuilder` / `TweenAnimationBuilder` builders, `CustomPainter.paint`, ticker callbacks, `addListener` on animations and scroll controllers, `onPanUpdate`-style gestures, scroll notifications |
| item | `itemBuilder:` and other list builders, `for` / `.map()` in `children:` |
| keystroke | `onChanged:`, `addListener` on a `TextEditingController` |
| build | `build` methods and everything they call or create |
| event | `Stream.listen`, `Timer.periodic`, other listeners |
| startup | `main` and what it awaits |
| cold | button handlers and other one-off callbacks |

Heat flows along calls, tear-offs and widget creation (creating `TripTile(...)` runs `TripTile.build`). Callbacks
(`onTap:` and other `on*` arguments) do not inherit the heat of the code around them. Each finding carries the chain,
e.g. `TripList.build → itemBuilder → TripTile.build → _price() → NumberFormat()`.

Rules built on it: `hot-allocation` (`DateFormat`, `NumberFormat`, `RegExp`, `TextPainter` in item/frame code),
`future-in-build`, `controller-in-build`. Later: `heavy-in-build` (sort, `where().toList()`, `jsonDecode`, `*Sync` I/O).
Impact becomes base cost × heat instead of a fixed label.

## 2. Flow rules

- `missing-dispose`: a `State` field holding an `AnimationController`, `TextEditingController`, `ScrollController`,
  `FocusNode`, `StreamSubscription`, `Timer` or `addListener` with no matching `dispose` / `cancel` / `removeListener`.
  Auto-fix adds the line (and `dispose()` if missing).
- `builder-child`: `AnimatedBuilder` / `ValueListenableBuilder` whose builder rebuilds a subtree that never reads the
  value. Auto-fix moves it into `child:`.
- `eager-list`: `ListView(children: ...)` or a `Column` in a scroll view built from runtime data. Auto-fix for the
  simple `.map(...).toList()` form.

## 3. Read/write map

For each `build`, which state fields it reads; for each `setState` / `emit` / `notifyListeners`, which it writes.

- `BlocBuilder` with no `buildWhen` that reads one field → `BlocSelector` (auto).
- `context.watch<T>()` with one field read → `context.select` (auto).
- `final mq = MediaQuery.of(context)` with only field reads → `sizeOf` and friends (auto).
- v2: `setState` in a big widget that changes a field only a small part reads → extract that part.

## 4. Deep measure (`dejank_meter` + `dejank measure`)

- Oversized images at runtime (`debugOnPaintImage`: decoded vs shown size, bytes wasted).
- Rebuild counts per file:line (widget creation locations) and their causes (who marked them dirty).
- Real frame times in profile mode (`debugProfileBuildsEnabled` works there), frame budget from the refresh rate.
- Join with scan: rank findings by measured cost; list hot spots no rule explains yet.

## Later

Asset check (images and SVGs far bigger than drawn, huge Lottie files), analyzer plugin (warnings while typing),
`--format json` / SARIF, `CachedNetworkImage` / `DecorationImage` / `Image.file` decode sizes.
