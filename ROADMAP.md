# Roadmap

> **Version:** 0.3.0 | **Updated:** 2026-07-06

Direction after the 0.1.0 release. Deferred items carry their reason from ARCHITECTURE.md (Scope → Deferred); nothing here is promised for a date. Shipped and refuted items leave this file — CHANGELOG.md records the former, `.probe/SYNTAX.md` the latter.

## Near

| Item                | Notes                                                                                                                                                                                                 |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Package publication | conda recipe + channel (the prototype's recipe retired with the reset); README install section firms up then                                                                                          |
| Comptime styles     | A `comptime`-parameterized paint could bake a constant style's entire open sequence at build time; the always-inline chain already folds constant styles at call sites, so measure before building it |

## Later

| Item                           | Blocked on / reason deferred                                                                                                    |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| Nesting-aware repaint (opt-in) | Requires rescanning every input on every paint — off the default path by design                                                 |
| OSC-8 hyperlink emitting       | Serves no current contract; stripping already handles incoming links                                                            |
| Native Windows package support | Upstream Mojo currently supports Windows through WSL; add native Windows only when the `mojo` package exists for `win-*`        |
| Windows console support        | The library's bytes are already correct; a consuming application must enable VT processing — document that recipe when it lands |
| Wide-glyph width (UAX #11)     | Belongs to a dedicated width library; `visible_width` stays code-point-based                                                    |
