## 0.1.1

- `shrinkwrap-in-column` now finds lists returned from `if` / `switch` and from state-management builders (`BlocBuilder`, Provider's `Consumer`, Riverpod, GetX, MobX), the usual BLoC screen shape. It no longer suggests `Expanded` for a `Column` inside a scroll view.
- List rules no longer flag a screen that a list item opens on tap through a helper method (a wrong warning).
- `dejank scan` exits with code 1 when it finds problems, for CI and pre-commit hooks.
- `dejank fix --dry-run` shows the diff without writing anything.
- With no path, `scan` and `fix` check `lib/`.
- `dejank measure` keeps `.dejank/` out of git by itself.
- "1 problem", not "1 problems".
- pub.dev screenshot.

## 0.1.0

First release.

- `dejank scan`: lists slow code with file:line, impact, and whether it can be fixed automatically.
- `dejank fix`: applies the safe fixes, shows a diff, and refuses any fix that would add an analyzer error.
- `dejank measure`: runs a test that uses `dejank_meter`, saves the numbers, and compares them with the last run.
- Six rules: `mediaquery-of`, `opacity-animation`, `image-cache-size` (auto), `shrinkwrap-in-column`, `intrinsic-in-list`, `serial-awaits-main` (suggest).
