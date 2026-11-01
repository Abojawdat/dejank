# dejank — "React Compiler for Flutter"

**One promise:** finds slow Flutter code, **fixes it for you**, and **proves it** with numbers
("this screen went from 340 rebuilds to 12").

- Owner: Mohammad Othman (GitHub **Abojawdat**). Explain things in simple English.
- Why this idea was chosen: ranked #2 most viral of 45 ideas, and the best one that can also be paid
  (open core). Every Flutter developer is a possible user. Full brainstorm: `docs/ideas-context.md`.
- Status (2026-10-31): phases 1–5 done (engine, all 6 v1 rules, demo app, measure). See "Build phases" below.
- Environment: Flutter 3.44.8 stable, Dart 3.12.2, macOS arm64.
- Name: `dejank` (CLI, command `dejank`) + `dejank_meter` (measure package), both free on pub.dev (checked
  2026-10-29). Renamed from `flutter_turbo`: the `turbo` command clashes with Turborepo, and "turbo" is crowded.

---

## Competitors (pub.dev, checked 2026-10-29)

| Package | Likes | Downloads/30d | Last release | What it is |
|---|---|---|---|---|
| dart_code_metrics | 936 | 57,261 | 2023-07 **discontinued** | Was the main Dart analysis tool; went paid as DCM |
| very_good_analysis | 773 | 1.28M | 2026-09 | Lint rule set (style + correctness), no performance fixes |
| custom_lint | 264 | 730,885 | 2025-09 | Framework for writing lint rules, not rules itself |
| solid_lints | 57 | 5,489 | 2026-10 | General best-practice lints |
| auto_const | 16 | 50 | 2023-02 (dead) | CLI that only adds `const` |
| flutter_perf_guard | 14 | 34 | 2026-05 | "Enterprise" runtime profiling toolkit |
| saropa_lints | 11 | 2,713 | 2026-10 | 2,332 rules, 254 quick fixes; security + a11y + perf |
| fluttrace | 7 | 39 | 2026-05 | Runtime frame timing analytics |
| flutter_risk_detector / flutter_quality_assist / flutter_deep_analyzer | 2–4 | 34–67 | 2026-05 | "Analyze everything" CLIs |
| flutter_build_tracker | 3 | 114 | 2025-05 | Runtime build counts |
| hyper_lint | 1 | 1,083 | 2024-01 (stale) | General lints |
| flutter_perf_lints | 0 | 58 | 2026-10 | Analyzer plugin that **flags** perf problems |

## What competitors failed at → what we do instead

1. **They flag, they don't fix.** Most only warn (`flutter_perf_lints`, the analyzer CLIs). saropa_lints has
   fixes for ~11% of its rules. → **Every rule ships with an auto-fix, or a clear "needs a human" suggestion with the fix shown.**
2. **No proof.** Nobody shows before/after numbers, so developers can't feel the win. →
   **`dejank measure` records rebuilds and frame times before and after. The numbers are the product and the marketing.**
3. **Noise.** Thousands of rules → people turn them off. → **Few rules, only high-impact performance ones, zero false positives.
   A wrong warning is a bug.**
4. **No identity.** "Architecture + security + accessibility + performance" tools mean nothing. → **Only performance. One promise.**
5. **Abandoned.** auto_const (2023), hyper_lint (2024), and dart_code_metrics went paid, but **still gets 57k downloads a
   month while discontinued**, so people want a free tool and nobody replaced it. → **Small scope we can maintain for years.**
6. **Measure-only tools stop at numbers.** fluttrace and flutter_build_tracker show slowness but don't point to the line or fix it.
   → **Connect the measurement to the exact code and the fix.**
7. **No launch.** None of them proved themselves on real apps. → **Run on big open-source Flutter apps and send PRs with
   "X% fewer rebuilds".**

**Don't rebuild what already exists:** adding `const` is already handled by the official `prefer_const_constructors` lint +
`dart fix --apply`. We just recommend turning it on; we don't re-implement it.

---

## v1 scope

Commands:
- `dejank scan` lists problems with file:line, impact, and whether it can be auto-fixed.
- `dejank fix` applies the safe fixes and shows a diff.
- `dejank measure` gives proof (before/after rebuild counts + frame times). Design to be decided in session 1.

Rules. **Safety level** = auto (safe to rewrite) or suggest (show fix, human decides):

| Rule | Change | Safety |
|---|---|---|
| mediaquery-of | `MediaQuery.of(context).size` → `MediaQuery.sizeOf(context)` (also `paddingOf`, `viewInsetsOf`, `orientationOf`, `devicePixelRatioOf`, `textScalerOf`, `platformBrightnessOf`). Avoids rebuilding on every keyboard animation frame. | auto, only when one property is read right after `.of(context)` |
| opacity-animation | `AnimatedBuilder(... Opacity(opacity: c.value, child: child))` → `FadeTransition(opacity: c, child: ...)` | auto, exact pattern only |
| image-cache-size | `Image.network(url, width: 100)` in lists without `cacheWidth` → add `cacheWidth` from width × devicePixelRatio | auto when width is a literal; suggest otherwise |
| shrinkwrap-in-column | `ListView(shrinkWrap: true)` inside `Column`/scroll view builds every item | suggest (slivers / `Expanded`) |
| intrinsic-in-list | `IntrinsicHeight` / `IntrinsicWidth` inside list items | suggest |
| serial-awaits-main | several independent `await`s before `runApp` → `Future.wait` | suggest only; order may matter (e.g. Firebase first) |

**v2 (the impressive one):** `setState` in a huge widget → extract only the part that changes into its own widget.
Also later: the auto "select" fixer (`context.watch<X>()` → `context.select(...)`) and an MCP server for AI coding agents
(same engine). Paid tier later: CI gate that blocks slow code in PRs + team reports.

## Engineering rules

- Tests per rule: fixture pairs (`input.dart` → `expected.dart`), plus "must not change" fixtures for false-positive cases.
- Never rewrite code we don't fully understand. When unsure, downgrade to suggest.
- Keep dependencies minimal (`package:analyzer`, `package:args`).
- No comments in code (fixtures keep their `// LINT` markers: the tests read them).
- Small commits with short titles, pushed after every new thing. No attribution lines.

## Decisions (made 2026-10-29)

1. **Engine:** plain CLI on `package:analyzer` (resolved AST, so we only touch real Flutter classes). IDE plugin later.
2. **Layout:** `dejank` (pure Dart CLI) at the root + `dejank_meter/` (Flutter dev dependency).
3. **`dejank measure`:** both. First the integration test + JSON before/after diff (exact proof), then a live
   rebuild overlay on top using the same counter.
4. **Demo app:** small fake shop app in `example/slow_app` that triggers every rule.
5. **Licence (2026-10-31): PolyForm Shield 1.0.0**, not MIT/AGPL. Goal: stop renamed copies (free or paid). Free to use
   anywhere; not OSI, so pub.dev gives 150/160 (owner accepted, 2026-10-31). Not for selling.

## Build phases

1. ✅ Engine (`lib/src/engine.dart`), CLI `scan`/`fix` (`bin/dejank.dart`), rule `mediaquery-of`, fixture tests.
2. ✅ Rules `opacity-animation`, `image-cache-size` (lists only, cacheWidth from real devicePixelRatio). `fix` now
   re-analyzes changed files in memory and refuses any fix that adds an analyzer error.
3. ✅ Rules `shrinkwrap-in-column` (builder lists only, and only with no height limit; walks through `if`/`switch`
   and state-management builders like `BlocBuilder`), `intrinsic-in-list`,
   `serial-awaits-main`. Engine `lib/src/project.dart` finds tile widgets / helper methods used inside lists
   (and what they use), skipping `onTap:`-style callbacks, so list rules also see code outside the list. Only
   `build` and `@override` methods make a list widget's code list code; helpers count only when called from them.
4. ✅ Demo app `example/slow_app` (200-product shop; all 6 rules fire, 4 auto-fixes; fixed copy analyzes clean).
5. ✅ `dejank_meter` + `dejank measure`. Proof on a real Android phone (2026-10-31), demo search test, before → after
   `dejank fix` (4 auto-fixes only): widget builds 213,677 → 14,051 (-93%), ProductTile 4,620 → 240 (-95%),
   avg build 22.9 → 7.7 ms (-66%), slow frames 43 → 6 of ~140 (-86%). Debug mode (the build hook needs it), so
   frame times are relative; build counts are exact. Second run with the pretty CLI (same day, the one in all
   images): 214,669 → 15,219 (-93%), slow frames 44 → 7 (-84%), avg build 27.1 → 8.9 ms (-67%).
6. Live rebuild overlay.
7. 🚧 Deep engine (plan: `docs/deep-engine.md`). Done: heat map `lib/src/heat.dart` (how often code runs, with the
   call chain) and rules `hot-allocation`, `future-in-build`, `controller-in-build`; flow rules `missing-dispose`,
   `builder-child`, `eager-list`; read/write rules `bloc-select` and stored `MediaQuery`. Every rule was checked by
   hand on 5 real apps, and `fix` was run on copies of them (0 new analyzer issues). Next: deep measure.

Published: `dejank` 0.1.3 on pub.dev (2026-11-01, by the GitHub Actions release flow; 0.1.2 was never published). `dejank_meter` not yet: needs one manual `dart pub publish`, then automated publishing with tag pattern `dejank_meter-v{{version}}`.

## Look and launch

- CLI output is pretty in a terminal (colors, numbered findings, emojis, gradient bar, "made with 💙 by Abojawdat")
  and plain when piped. `NO_COLOR` / `FORCE_COLOR` respected. Plain output must stay stable (CI logs, tests).
- `site/` is the live demo on GitHub Pages (`demo.yml`): a browser terminal that replays the real recordings in
  `site/out/*.ans`. Re-record them with `FORCE_COLOR=1 dejank ... > site/out/<name>.ans` in `example/slow_app`.
- `tool/render_terminal.py` (Pillow, macOS fonts) turns those recordings into `art/scan.png`, `fix.png`,
  `measure.png`, the animated `session.webp` (README hero, pub.dev screenshot) and `social.png` (GitHub preview).
- pub.dev loads README images through its own cache; a URL it once saw as 404 stays broken for a while, so new
  images get new file names.

## Backlog (from a review on a real BLoC app, 2026-10-31)

- Ignore comment `// dejank:ignore <rule>`; tag findings in code nothing uses as "unused, delete it".
- Finer impact (a helper method is not `build`); `--format json` / SARIF for GitHub annotations.
- measure: slow-frame budget from the real refresh rate (120 Hz = 8.3 ms), not fixed 60 Hz; try profile mode with
  timeline build events for real frame times.
- Rules: `FutureBuilder(future: load())` refetches every rebuild; `ListView(children: items.map(...).toList())`
  (auto → builder); images sized by a parent / `DecorationImage(NetworkImage)` / `CachedNetworkImage` without
  `memCacheWidth`; `AnimatedBuilder` with unused `child`; `final mq = MediaQuery.of(context)` with only field reads.

## How the code works

- `project.heat.at(node)` says how often a node runs (`Heat.frame` … `Heat.cold`) and the chain that makes it hot.
  Base sources live in `heat.dart`. It is conservative on purpose (a wrong "every frame" is a bug): only builder-style
  closures and sync helpers (`map`, `setState`…) inherit heat, other closures and tear-offs are callbacks, calls in
  `if`/`?:` drop frame heat to event, and `async` functions never get more than event. Checked on 5 real apps.
- A rule is a class in `lib/src/rules/`, added to `allRules` in `engine.dart`. It returns `Finding`s; a finding with
  `edits` is auto-fixable, one without is "suggest" (the message shows the fix).
- Tests: `dart test`. Fixtures live in `test/fixtures/lib/<rule_name>/` (a real Flutter package, so fixes are
  type-checked against real Flutter). `input.dart` lines ending in `// LINT` must be flagged, all others must not;
  `expected.dart` is the result after fixing.
- Run: `dart run bin/dejank.dart scan <path>` / `fix <path>`. The target project needs `flutter pub get` first.
- Release: bump `version:` in `pubspec.yaml` or `dejank_meter/pubspec.yaml` + CHANGELOG, push to main. `release.yml`
  tags it (`v1.2.3` / `dejank_meter-v1.2.3`) and starts `publish.yml` (GitHub environment `pub.dev`). The root
  `.pubignore` also applies to `dejank_meter/`, so never list `dejank_meter/` in it. A folder with a `.pubignore`
  ignores its `.gitignore` for publishing, so `build/` and `.dart_tool/` must be listed in `.pubignore` too.
