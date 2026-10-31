# dejank example

[`slow_app`](https://github.com/Abojawdat/dejank/tree/main/example/slow_app) is a 200-product shop that triggers every rule.

```sh
cd example/slow_app
flutter pub get
dejank scan
dejank measure integration_test/search_test.dart -d <device>
dejank fix
dejank measure integration_test/search_test.dart -d <device>
```

On an Android phone the second `measure` shows 93% fewer widget builds and 84% fewer slow frames.
