# Flutter Package Ideas — Context for Claude

> Read this before helping me build one of these ideas. It is the summary of a brainstorm chat
> (2026-10-29) where we explored, checked and ranked 45 package ideas. The ranked PDF version is
> `~/Desktop/Flutter Package Ideas Ranked.pdf`.

## My pick (fill this in when you start)

- **Chosen idea:** #2 Flutter Compiler, the "React Compiler for Flutter" (brand: `dejank`)
- **Why I chose it:** every Flutter developer is a user, nobody owns the space (DCM went paid, best free perf lint has
  11 likes), "X% fewer rebuilds" numbers are the marketing, and it can be paid later (open core).
- **Free or paid plan:** open core: free CLI and rules; paid CI gate and team reports later
- **v1 scope:** `dejank scan` / `dejank fix` / `dejank measure` with 6 rules. See `~/Desktop/future packages /flutter_turbo/CLAUDE.md`
- **Started on:** 2026-10-29

**Second pick:** #19 LeakCanary for Flutter (brand: `leak_hound`), project at `~/Desktop/future packages /leak_hound`. Free; builds
reputation with senior devs; engine already exists in `leak_tracker`, the missing part is the zero-setup in-app
experience. May later merge into `dejank` as `dejank leaks`.

---

## Who I am

- Mohammad Othman (**Abojawdat** on GitHub), Flutter developer from Iraq.
- Published packages: `iraqi_license_plate` (photoreal plates + data model), `iraqi_bank_card_scanner`
  (on-device OCR with multi-frame verification), `duo_dynamic_sizing` (foldable iPhone layout, hinge
  and posture), `bank_card_3d` (3D Visa/Mastercard widgets). `touring_package` (app tours) is unfinished.
- I've built real apps: delivery driver/customer apps (Wasel, Wassilni, Elmared), so I know bad
  networks and cheap Android phones first-hand.
- My Flutter structure skills: `/wsl` and `/structure-sensei`. Build workflows: `/jojo`, `/m7md-3me`.

## What I was looking for

1. Global ideas, not Iraq-only.
2. Things that **fix real problems** or that nobody has done (or that people tried and failed).
3. **Viral** — something that makes a big name.
4. Most excited by **code generators / annotations** in the style of build_runner, injectable,
   freezed: "write one line, the generator writes the boring, error-prone part".
5. "God level": things that stop real production incidents (crashes, lost money, legal problems),
   and OS-level problems Flutter can't solve today.

## How ideas were judged

**Viral score (1–10)** was based on:
- **10-second demo** — can one short video or screenshot explain it? (weighted most)
- **Audience** — every Flutter dev > Flutter web users > one industry.
- **Effort to try** — one line / one command spreads; a setup guide doesn't.
- **Timing** — AI agents, new laws (EU Accessibility Act, privacy manifests), shutdowns (Firebase
  Dynamic Links, Realm, Isar).
- **Competition** — checked on pub.dev on 2026-10-29. Many ideas have tiny AI-made packages with
  0–5 likes. *Existing is not the same as solved*; winning = quality + real benchmarks + docs + launch.

**Selling truths we agreed on:**
- Flutter devs rarely pay for packages; pub.dev has no paid packages → paid means a hosted service
  or a private package server with tokens.
- Companies pay for: dashboards/history, CI checks, compliance/legal safety, hosted services,
  support, and anything that saves hiring Swift/Kotlin developers.
- Model that works: **open core** (free package spreads, paid team/cloud features). Proof: DCM,
  Shorebird, PowerSync; outside Dart: Codecov, Sentry, PactFlow.
- Paid fails when: a free option is "good enough", Google's Flutter/Dart team ships it officially,
  maintenance eats your time, or the Flutter company market is too small.
- **Key insight:** the most viral ideas are NOT the most profitable. Use free viral tools to build
  an audience, then sell the boring, critical ones to companies.

## Strategy decisions

- **Don't ship many small packages. Ship under a few brands:**
  - `dejank` — one performance CLI (`dejank fix`, `dejank json`, `dejank fonts`, `dejank assets`, `dejank web`).
  - **"Production-safe Flutter"** — one build_runner suite of annotations (`@ApiContract`, `@Guard`,
    `@Sensitive`, `@Restorable`, `@Stored`, `@Collects`, `@Offline`, `@DeepLink`, `@Env`, `@KillSwitch`).
- **Recommended path:** Month 1 launch #1 React Scan (free, attention) → months 2–4 build #2 Flutter
  Compiler with #3 and #4 inside it (open core) → then one paid business: #22 `@ApiContract` (biggest
  problem) or #10 Lighthouse CI (easiest SaaS). Wild card: #8 OS surface compiler (deepest moat).
- **Not included:** the app-hardening ideas from a side topic (I said I wasn't asking for security).

---

## Full ranking (most → least viral)

| # | Idea | Viral | Sell it? | Paid model |
|---|------|------|----------|------------|
| 1 | React Scan for Flutter | 10 | No | Free (funnel) |
| 2 | Flutter Compiler (auto performance fixer) | 9 | **Yes** | Open core |
| 3 | AI coding agent performance guard (MCP) | 9 | No | Free, part of #2 |
| 4 | Auto "select" fixer | 8 | Maybe | Paid feature of #2 |
| 5 | Faster json_serializable (drop-in) | 8 | No | Free |
| 6 | `@Undoable` (undo/redo + time travel) | 8 | No | Free |
| 7 | Test recorder | 8 | Maybe | Freemium |
| 8 | OS surface compiler (home widgets & Live Activities in Dart) | 8 | **Yes** | Open core |
| 9 | Flutter web text layer (Ctrl+F, translate, select) | 8 | No | Free |
| 10 | Lighthouse for Flutter (CI score + PR comments) | 7 | **Yes** | SaaS |
| 11 | Bundlephobia for pub.dev | 7 | Maybe | Free site + paid API |
| 12 | One-command asset optimizer | 7 | No | Free |
| 13 | Permissions as code | 7 | No | Free |
| 14 | `@Replay` (reproduce production crashes) | 7 | Maybe | SaaS |
| 15 | `device_tier` (low-end phone mode) | 6 | No | Free |
| 16 | Demo mode (fake backend from your API) | 6 | No | Free |
| 17 | `@Optimistic` (instant buttons) | 6 | No | Free |
| 18 | Font shrinker (Arabic/CJK) | 6 | No | Free |
| 19 | LeakCanary for Flutter | 6 | No | Free |
| 20 | Live Text inside Flutter images | 6 | No | Free |
| 21 | Lottie → Dart code | 6 | No | Free |
| 22 | `@ApiContract` (crash-proof models + backend contract) | 5 | **Yes** | Open core + SaaS |
| 23 | `@Guard` (no double payments, no stale results) | 5 | No | Free |
| 24 | Auto deferred routes (Flutter web) | 5 | No | Free |
| 25 | Background waste detector | 5 | No | Free |
| 26 | State machines that draw diagrams | 5 | Maybe | Free, paid editor later |
| 27 | `@DeepLink` (links that always work) | 5 | **Yes** | SaaS (hosted links) |
| 28 | `@KillSwitch` | 4 | No | Free |
| 29 | `@Offline` (outbox) | 4 | Maybe | Free, paid sync later |
| 30 | `@Sensitive` (personal data never leaks) | 4 | Maybe | Privacy suite bundle |
| 31 | `@Restorable` | 4 | No | Free |
| 32 | ANR blame | 4 | Maybe | Free |
| 33 | `@Env` + release guard | 4 | Maybe | Part of #10 |
| 34 | `@Collects` (privacy forms that write themselves) | 4 | **Yes** | B2B |
| 35 | `@Stored` (storage migrations) | 3 | No | Free |
| 36 | `touch_accommodations` | 3 | No | Free |
| 37 | EU accessibility compliance reports | 3 | **Yes** | B2B |
| 38 | `@EvictOnPressure` | 3 | No | Free |
| 39 | Supply-chain scanner for pub.dev | 3 | Maybe | SaaS |
| 40 | `meter_reader` (on-device meter OCR) | 3 | **Yes** | B2B license |
| 41 | `address_form` (world address input) | 3 | No | Free |
| 42 | App Clips from Flutter screens | 3 | No | Free |
| 43 | `world_license_plates` | 2 | No | Free |
| 44 | `signed_qr` (offline-verifiable QR) | 2 | Maybe | Free, paid issuing later |
| 45 | Isar/Realm successor database | 2 | Maybe | Open core + paid sync |

---

## Idea details (design notes from the chat)

Competition numbers are from pub.dev on 2026-10-29. **Re-check before building.**

### 1. React Scan for Flutter
- One line in `main()`. Widgets that rebuild flash with a colored box + counter, live.
- Build on Flutter's debug hook `debugOnRebuildDirtyWidget`.
- Competition: `flutter_rebuild_scan`, `widget_rebuilds_inspector` (0 likes). DevTools has counts, hidden in IDE.
- Role: free attention magnet and front door to #2.

### 2. Flutter Compiler (auto performance fixer) — "React Compiler for Flutter"
- CLI + analyzer plugin (`package:analyzer`, Dart's new analyzer plugin system). Finds AND rewrites:
  - `MediaQuery.of(context)` → `MediaQuery.sizeOf(context)` (whole screen rebuilds during keyboard animation otherwise)
  - missing `const`; `Opacity` in animations → `FadeTransition`
  - `shrinkWrap: true` lists inside `Column`; `IntrinsicHeight` in list items
  - `setState` in huge widgets → extract the changing part into its own widget (the hard, impressive one)
  - serial `await`s in `main()` before `runApp` → `Future.wait`
  - `Image.network` in lists without `cacheWidth`
- Proves results with before/after rebuild counts. Marketing: run on big open-source Flutter apps, open PRs with numbers.
- Competition: perf lint packages with tiny adoption (best ~11 likes). DCM went paid.
- Risk: one broken auto-rewrite destroys trust; Dart team could add similar fixes.

### 3. AI coding agent performance guard (MCP)
- MCP server + rules. Claude Code / Cursor / Copilot call it after writing a widget; returns problems + fixed code.
- Catches AI's typical slow Flutter: `Column` in `SingleChildScrollView` building 1,000 items, `MediaQuery.of`, no `const`.
- Same engine as #2. Hook: "AI writes slow Flutter. This fixes it."

### 4. Auto "select" fixer
- Reads `build()`, sees which state fields are used, rewrites `context.watch<Cart>()` → `context.select((Cart c) => c.total)`
  (Riverpod: `ref.watch(provider.select(...))`).
- Nothing found on pub.dev. Best as a paid feature of #2.

### 5. Faster json_serializable (drop-in)
- Same `@JsonSerializable` annotations; generated code parses bytes directly into objects, no `Map<String, dynamic>` in between → less memory/GC, no lag on big responses.
- `crimson` proved the idea and died (last update Jan 2025, ~50 downloads/month). Publish benchmarks.

### 6. `@Undoable`
```dart
@Undoable(limit: 50)
class EditorState { final String text; final Color color; }
```
- Generates `undo()`, `redo()`, `canUndo`, grouping of fast edits (typing "hello" = 1 step), Ctrl+Z / Cmd+Shift+Z, debug time-travel slider. Nothing on pub.dev.

### 7. Test recorder
- Record mode → tap around → writes integration test code with finders and on-screen checks.
- Competition: `automated_integration_test` (3 likes). **Maestro** already records flows for mobile apps incl. Flutter (but doesn't write Dart test code).
- Risk: recorded tests are brittle when UI changes.

### 8. OS surface compiler (home widgets & Live Activities in Dart)
- Problem: Flutter can't draw outside its window. Home/lock screen widgets, Live Activities, Dynamic Island, Android 16 Live Updates, watch complications, Wear tiles need native SwiftUI/Kotlin. They run in a separate small process with a tiny memory limit, so the Flutter engine can't run there (OS rule).
- Past attempts failed: `home_widget` (2,221 likes, ~300k downloads/month) renders Flutter to a static image (not tappable, stale, no dark mode); `home_widget_generator` (4 likes) and `live_activity_kit` (6 likes) cover one surface each with a custom DSL and no preview.
```dart
@OsSurface(sizes: [Size.small, Size.medium], liveActivity: true)
class DeliveryStatus extends SurfaceWidget<DeliveryData> {
  Widget build(DeliveryData d) => Column(children: [
    Text(d.driverName),
    ProgressBar(d.progress),
    Button('Call driver', action: CallDriver()),
  ]);
}
```
- Architecture: (1) limited real Flutter widgets that also render in-app as live preview; (2) build-time compiler via Dart analyzer → SwiftUI (WidgetKit/ActivityKit) + Kotlin (Glance/Live Updates/Wear tiles), lint error for unsupported widgets; (3) typed data bridge (App Groups / DataStore) with generated Swift/Kotlin types; (4) buttons → App Intents / Glance actions → Dart callback or deep link; (5) same schema generates push payloads for Live Activity updates; (6) auto-creates the Xcode widget extension target, App Groups, entitlements; (7) preview simulator for sizes, lock screen, dark/tinted.
- Steps: v1 home widgets iOS+Android with 7 widgets + deep-link taps → v2 Live Activities/Dynamic Island/Live Updates → v3 Watch/Wear.
- Risks: `build()` must be data-driven layout only; Xcode project editing is fragile; yearly API changes.

### 9. Flutter web text layer
- PDF.js trick: invisible real HTML text positioned exactly over Flutter's pixels so browser Ctrl+F, selection, copy and read-aloud work. Collect visible text + positions when scrolling stops.
- Experimental: catch Chrome Translate rewriting the layer and feed translations back into Flutter. May turn out impossible — prototype first.
- Competition: `find_in_page` (6 likes) is an in-app search bar only.

### 10. Lighthouse for Flutter
- Runs on every PR: 0–100 score for performance, size, startup, accessibility, plus comments like "startup +120ms, app +2.1 MB".
- Competition: `flutter_lighthouse` (0 likes). Model: free for open source, paid for private repos (Codecov-style).
- Risks: device run costs; noisy CI numbers.

### 11. Bundlephobia for pub.dev
- Website + CLI: MB added, startup cost, transitive deps, native code, **permissions a package adds**. Needs building each package in a sample app on servers.

### 12. One-command asset optimizer
- PNG→WebP, resize to largest displayed size, 2x/3x, blurred placeholders. A `dejank` command.

### 13. Permissions as code
```dart
@NeedsPermission(Permission.camera, reason: 'To scan your bank card')
class CardScanScreen extends StatelessWidget { ... }
```
- Generates Info.plist usage strings (translated), AndroidManifest entries, the Podfile macros `permission_handler` needs, typed `AppPermissions.camera.request()` with "open Settings" flow; removes unused permissions. Nothing on pub.dev.

### 14. `@Replay`
- Records state changes + API responses in a rolling buffer (with `@Sensitive` fields masked); on crash, uploads a file that replays the app exactly to the crash.
- Competition: Sentry/Datadog/Clarity record video, not state; `flutter_bug_replay` (0 likes).

### 15. `device_tier`
- At startup measure RAM, CPU cores, Android low-RAM flag, refresh rate, thermal state, battery saver → `context.tier` (low/mid/high) + auto switches (no blur, smaller image cache, smaller decode, shorter animations). Like Facebook's Android "Year Class". 0 results on pub.dev.

### 16. Demo mode
```dart
@DemoMode()
@RestApi()
abstract class ShopApi { Future<List<Product>> getProducts(); }
```
- Generates a fake implementation with realistic data by field name (`price`, `email`, `avatarUrl`), fake delay/errors; `--dart-define=DEMO=true`. For store reviewers, UI work before backend, sales demos.

### 17. `@Optimistic`
```dart
@Optimistic(rollbackOnError: true)
Future<void> likePost(String id);
```
- UI updates instantly, request in background, rollback + error on failure, double taps ignored.

### 18. Font shrinker
- Scans ARB/l10n + string literals, subsets UI fonts to used glyphs (Arabic/CJK fonts are 1–15 MB). User-typed/server text still needs full fonts. `font_subset` (1 like) only wraps Google's binary.

### 19. LeakCanary for Flutter
- Debug mode: detects screens/controllers retained after leaving, shows retaining path via VM service, flags forgotten `dispose()` (controllers, streams, timers). `leak_tracker` (Flutter team) is test-only.

### 20. Live Text inside Flutter images
- VisionKit (iOS) / ML Kit (Android) → text positions → selectable Flutter text overlay on the image.

### 21. Lottie → Dart code
- Compile Lottie JSON to Flutter painting code at build time. `dotdart` started 2026-10-28 (2 likes) — it's a race.

### 22. `@ApiContract` — strongest business idea
```dart
@ApiContract('GET /orders')
class Order { final String id; final double total; final OrderStatus status; }
```
- Crash-proof parsing (wrong type/null → fallback, unknown enum → `unknown`), a report for every mismatch (field, endpoint, app version, % users), and a **contract file the backend runs in CI** ("removing `total` breaks app versions 2.1–2.4, 38% of users").
- Fixes: `type 'Null' is not a subtype of type 'String'` crashes in old app versions that stay installed for years.
- Competition: `safe_json_serializable` (2 likes, parsing only), `pact_dart` (5 likes, manual). PactFlow proves paid contract testing.

### 23. `@Guard`
```dart
@Guard.singleFlight()   // second tap while running → ignored
@Guard.idempotent()     // retry sends same key → server charges once
Future<Receipt> pay(Cart cart);

@Guard.latestOnly()     // old results never replace newer ones
Future<List<Product>> search(String query);
```
- Backend must accept an idempotency key (Stripe-style). Competition: `async_guard` (5 likes), manual wrapping.

### 24. Auto deferred routes (Flutter web)
- Generate `deferred as` imports per route + loading UI. Mostly helps web. `go_router_deferred` (4 likes) is manual.

### 25. Background waste detector
- Track every Timer via Dart `Zone` (createTimer/createPeriodicTimer with stack traces); report timers/animations/streams alive after leaving a screen, and work running in background.

### 26. State machines that draw diagrams
- Typed machine where impossible states can't happen + Mermaid diagram updated in README every build. XState-style.

### 27. `@DeepLink`
```dart
@DeepLink('/orders/:id', requiresAuth: true, survivesInstall: true)
class OrderScreen extends StatelessWidget { ... }
```
- Generates routes, `apple-app-site-association` + `assetlinks.json`, entitlements + intent filters, login guard (remember link, open after login), tests per link, self-hosted install-surviving links (Firebase Dynamic Links shut down Aug 2025). `deeplink_setup` (6 likes) only does config files.

### 28. `@KillSwitch`
```dart
@KillSwitch('new_checkout', fallback: LegacyCheckout)
class NewCheckoutScreen extends StatelessWidget { ... }
```
- Remote check with offline cache, auto fallback, version rules, list of all switches for on-call.

### 29. `@Offline`
```dart
@Offline(retry: Retry.exponential, survivesRestart: true, conflict: Conflict.serverWins)
Future<void> markDelivered(String orderId, Proof proof);
```
- Persisted outbox surviving app kill, retry when online, idempotency key, conflicts, per-item "waiting to sync" badge, resumable background photo uploads.

### 30. `@Sensitive`
```dart
class User {
  @Sensitive.pii()    final String email;
  @Sensitive.secret() final String token;
  @Sensitive.card()   final String cardNumber;
}
```
- Masks in `toString`, logs, Crashlytics, Sentry, analytics, Dio logger; lint error if card data goes to analytics; GDPR data map. Bundle with #34.

### 31. `@Restorable`
```dart
class _CheckoutState extends State<Checkout> with _$CheckoutRestoration {
  @Restorable() final name = TextEditingController();
  @Restorable() int step = 0;
}
```
- Generates all `RestorationMixin` code so forms survive Android killing the app.

### 32. ANR blame
- Watchdog thread detects stuck main thread; every plugin message handler wrapped so the report names the plugin + method ("`some_plugin.getAll` froze main thread 3.2s"). Play lowers visibility above 0.47% user-perceived ANR rate. Check Sentry's features first.

### 33. `@Env` + release guard
```dart
@Env(prod: 'https://api.shop.com', staging: 'https://staging.shop.com')
static late final String apiUrl;
```
- Release build fails on staging/localhost URLs, `pk_test`/`sk_test` keys, body logging, reachable debug screens, cleartext HTTP.

### 34. `@Collects`
```dart
@Collects(Data.email, purpose: Purpose.account, linkedToUser: true)
@Collects(Data.preciseLocation, purpose: Purpose.appFunctionality)
@RequiresConsent(Consent.analytics)
class UserRepository { ... }
```
- Generates `PrivacyInfo.xcprivacy`, Play Data Safety answers, privacy policy data section, consent gate; checks plugins' privacy files. Liability: needs disclaimers / legal review.

### 35. `@Stored`
```dart
@Stored(since: 3, renamedFrom: 'auth_token')
String? sessionToken;
```
- Typed storage, migration chain from any old version, generated upgrade tests (v1→v5) in CI.

### 36. `touch_accommodations`
- App-wide hold duration, ignore repeated taps, first/last touch location (like iOS Touch Accommodations) for tremor/Parkinson's/older users.

### 37. EU accessibility compliance reports
- Runs in widget tests; outputs a report for the European Accessibility Act (enforced since June 2025). Automated checks can't guarantee full compliance — be honest about limits.

### 38. `@EvictOnPressure`
```dart
@EvictOnPressure(priority: 2)
final productCache = <String, Product>{};
```
- On OS memory warning, empties annotated caches in priority order and logs what was freed.

### 39. Supply-chain scanner for pub.dev
- Flags packages with build hooks, new network/process calls in updates, maintainer changes, lookalike names. `pubguardian` (3 likes).

### 40. `meter_reader`
- On-device OCR for electricity/water/gas meters: 7-segment LCD digits and rolling drum digits (half-turned wheel). Reuse multi-frame voting from my card scanner. Needs a small trained digit model. `odometer_scanner` uses cloud Gemini; paid SDKs sell this to utilities.

### 41. `address_form`
- Right address form per country from Google's open libaddressinput data (field order, required fields, postal regex). `address_formatter` only formats output.

### 42. App Clips from Flutter screens
- Pick screens → generate App Clip target → tree-shaken build → fail if over Apple's size limit, naming the package that made it too big. iOS only (Android Instant Apps shut down).

### 43. `world_license_plates`
- Extend `iraqi_license_plate` to EU, Gulf and US plates; today pub.dev has one package per country.

### 44. `signed_qr`
- Signed data in a QR, verifiable offline (CBOR + COSE + Base45 like EU COVID certificates). Use an audited crypto package, never custom crypto.

### 45. Isar/Realm successor database
- Fast, maintained, encrypted local DB with sync. Realm deprecated (2024), Isar abandoned (`isar_community` ~108k downloads/month). Years of work; drift/ObjectBox cover most needs.

---

## Instructions for Claude when I start one

1. Ask me which idea (or read "My pick" above) and confirm the v1 scope before writing code.
2. **Re-check pub.dev** for new competitors — numbers here are from 2026-10-29.
3. Start with the smallest version that proves the idea (a demo I can record), then expand.
4. Use my Flutter conventions (`/wsl` or `/structure-sensei`) when I ask for them.
5. Keep explanations in simple English.
