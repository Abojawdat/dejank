## 0.1.0

First release.

- `dejank scan`: lists slow code with file:line, impact, and whether it can be fixed automatically.
- `dejank fix`: applies the safe fixes, shows a diff, and refuses any fix that would add an analyzer error.
- `dejank measure`: runs a test that uses `dejank_meter`, saves the numbers, and compares them with the last run.
- Six rules: `mediaquery-of`, `opacity-animation`, `image-cache-size` (auto), `shrinkwrap-in-column`, `intrinsic-in-list`, `serial-awaits-main` (suggest).
