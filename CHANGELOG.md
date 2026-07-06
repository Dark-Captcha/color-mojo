# Changelog

All notable changes to color-mojo. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow SemVer once 1.0.0 lands.

## [0.3.0] — 2026-07-06

### Changed

- Development now depends on the full `mojo` Pixi package instead of `mojo-compiler`, matching current Mojo installation guidance and ensuring the standard library is available in fresh environments.
- Implementation constructors are hidden from generated docs and normalize invalid direct construction into safe internal states.
- Disabled-path performance wording now distinguishes zero-allocation `paint_into` from string-returning `paint`, which still returns a plain copy.

### Added

- A black-box public-surface test that imports only the seven package-root names from `color`.

## [0.2.0] — 2026-07-03

### Added

- `ColorLevel.resolve(*, is_tty, no_color, force_color, clicolor, clicolor_force, colorterm, term)` — the same standards-honoring ladder as before, as a pure function of explicitly supplied signals. Deterministic, unit-testable without touching the process (the test suite no longer calls `setenv` at all), and comptime-evaluable for build-time-fixed deployments. The application gathers the signals — `std.os.getenv` / `std.os.isatty`, a config file, CLI flags — and the README shows the one-liner wiring.
- `strip_escapes` / `visible_width` now consume ECMA-48 §5.6 command strings — DCS (`ESC P`), SOS (`ESC X`), PM (`ESC ^`), APC (`ESC _`) — to their `ST` terminator, exactly as a terminal does. Previously only the two opening bytes were removed, so sixel data or tmux passthrough payloads leaked into "visible" output. BEL remains a terminator for OSC only.
- Resolution honors `clicolor="0"` (disables unless a force flag is set) and numeric `force_color` levels: `1`/`2`/`3` floor the tier at ANSI16/ANSI256/truecolor — supports-color semantics, so a richer `colorterm`/`term` announcement still wins, and `term="dumb"` still vetoes everything.
- `Painter.resolve(*, is_tty, …)` — `from_level(ColorLevel.resolve(...))` in one call, so a terminal application's startup line stays a single expression.

### Changed

- Rendering is one pass: the SGR open sequence is assembled once into a comptime-bounded stack buffer that both sizes and fills the output — `paint` keeps its single exact-length allocation, and `paint_into` now allocates nothing at all.
- The render chain is `@always_inline` end to end: a compile-time-constant style (every sugar method) folds its emission into a few byte stores, and a held style hoists its downgrade and open sequence out of the caller's loop. Measured medians: named paint ~25 → ~8 ns, RGB downgraded through a `Painter` ~30 → ~8 ns (PERF.md).
- `ansi256_to_named16` reads a 256-byte table built in the compile-time interpreter instead of searching sixteen candidates per call — verified byte-identical by the 5,832-point differential sweep.

### Removed

- **All process-environment access.** The library is now pure: no `getenv`, no `isatty`, no global state — a library-side probe couples every caller to ambient process state and can contradict the host application's own configuration. `Painter.detect(fd)` and the thirteen module-level one-liners (`red` … `strikethrough`), whose whole purpose was the per-call probe, are gone. The public surface is seven names.

### Fixed

- `FORCE_COLOR=false` now disables color like `FORCE_COLOR=0`; previously any non-`0` value — including `false` — forced color on.

## [0.1.0] — 2026-07-02

First release — a ground-up library, written new. An earlier unreleased prototype was retired before this release; the comparison section below references it where the difference is instructive.

### Added

- `Color` — sixteen named constants, `ansi256(index)`, keyword-only `rgb(red=, green=, blue=)`, `from_hex("#rrggbb")`, and ladder-walking `downgrade_to(level)`.
- `Attribute` — the eight SGR text attributes as a one-byte set combined with `|`.
- `Style` — immutable fluent builder; verbatim `paint` (one exact-length allocation, no `raises`) and `paint_into[W: Writer]` (the text body streams unbuffered; only the small fixed-size open sequence is materialized).
- `Painter` — detect-once capability handle (`detect(fd=1)`, `plain()`, `from_level`), capability-honest `paint`/`paint_into` with automatic RGB → xterm-256 → named-16 downgrading, and 24 sugar methods.
- Thirteen module-level one-liners (`red` … `strikethrough`) that probe the destination per call.
- `strip_escapes` — terminal-accurate removal of CSI, OSC (BEL- and ST-terminated, including OSC-8 hyperlinks), and plain escape sequences, with aborted-sequence recovery.
- `visible_width` — UTF-8 code-point counting (RFC 3629), escapes zero-width.
- Detection ladder per destination: `NO_COLOR` > force flags (`0` disables, never forces) > TTY > `TERM=dumb` veto > `COLORTERM` > `TERM`.
- `references/` — vendored RFC texts and the standards map behind every emitted byte.
- `.probe/` — toolchain findings proven by runnable files, including the quantization reference implementation and its 5,832-point differential sweep.
- License: Apache-2.0 WITH LLVM-exception — the same terms as Mojo itself.

### Compared with the retired prototype

- Full-name public surface: `Attribute` (prototype: `Attr`), `foreground`/`background` (`fg`/`bg`), `STRIKETHROUGH` (`STRIKE`), `strip_escapes` (`strip` — stdlib collision), `ANSI16` (`ANSI8`).
- Capability detection defaults to stdout (`fd=1`), where `print` goes — the prototype gated on stderr and leaked escapes into piped stdout.
- The paint chain no longer `raises`, and rendering is one exact-length fill-in-place allocation (the prototype buffer-appended, then converted).
- Capability logic lives only in `Painter` — the prototype's `Support` struct, level-blind helper semantics, and public raw-SGR `Color.named(code)` have no successors.
