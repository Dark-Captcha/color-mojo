# Roadmap

> **Version:** 0.1.0 | **Updated:** 2026-07-02

Direction after the 0.1.0 release. Deferred items carry their reason from ARCHITECTURE.md (Scope → Deferred); nothing here is promised for a date.

## Near

| Item                        | Notes                                                                                                                           |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Package publication         | conda recipe + channel (the prototype's recipe retired with the reset); README install section firms up then                    |
| macOS platform              | Detection and rendering are POSIX-generic already; needs CI and a platform entry in `pixi.toml`                                 |
| Comptime-prerendered styles | A `comptime` `Style` could bake its open sequence at build time, making `paint` a pure concat — the biggest remaining perf idea |

## Later

| Item                           | Blocked on / reason deferred                                                                                                     |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- |
| SIMD code-point counting       | `visible_width` run counting is scalar today (~20 ns); optimize when a real workload demands it                                  |
| Stack-built open sequence      | Removes `paint_into`'s one small allocation; `StringSlice` over stack storage is probed working (`.probe/SYNTAX.md`, finding 12) |
| Nesting-aware repaint (opt-in) | Requires rescanning every input on every paint — off the default path by design                                                  |
| OSC-8 hyperlink emitting       | Serves no current contract; stripping already handles incoming links                                                             |
| Windows console support        | POSIX first; needs VT enablement plumbing                                                                                        |
| Wide-glyph width (UAX #11)     | Belongs to a dedicated width library; `visible_width` stays code-point-based                                                     |
