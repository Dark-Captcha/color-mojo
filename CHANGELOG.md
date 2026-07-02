# Changelog

All notable changes to color-mojo. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow SemVer once 1.0.0 lands.

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
