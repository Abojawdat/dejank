# slow_app

A small shop app written the way a lot of real Flutter code is written: it works, but it's slow.
It's the "before" for flutter_turbo's demo. Every v1 rule finds something here:

| Where | Problem | Rule |
|---|---|---|
| `product_tile.dart` | `MediaQuery.of(context).size.width`: all 200 tiles rebuild on every keyboard frame | `mediaquery-of` (auto) |
| `product_tile.dart` | 800 px photos decoded at full size for 96 px thumbnails | `image-cache-size` (auto) |
| `product_tile.dart` | `IntrinsicHeight` in every tile | `intrinsic-in-list` |
| `home_screen.dart` | `MediaQuery.of(context).padding` | `mediaquery-of` (auto) |
| `home_screen.dart` | Sale banner pulses with `AnimatedBuilder` + `Opacity` | `opacity-animation` (auto) |
| `home_screen.dart` | `ListView.builder(shrinkWrap: true)` in a `SingleChildScrollView`: builds all 200 tiles | `shrinkwrap-in-column` |
| `main.dart` | Two independent awaits before `runApp` | `serial-awaits-main` |

```sh
flutter pub get
dart run ../../bin/turbo.dart scan .   # 7 problems: 4 auto-fixable
dart run ../../bin/turbo.dart fix .    # applies the 4 safe fixes
```
