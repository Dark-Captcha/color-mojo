# Performance — color-mojo

> **Version:** 0.3.0 | **Updated:** 2026-07-06

Hot-path latency, measured by `pixi run benchmark` (N = 200,000 per path, median of nine runs, x86-64 Linux, Mojo `1.0.0b3.dev2026070506`). Run-to-run spread on this machine is roughly ±10%; treat single-nanosecond differences as noise.

---

## Current

| Path                                    | ns/call | Notes                                                                                             |
| --------------------------------------- | ------- | ------------------------------------------------------------------------------------------------- |
| `Style.paint` — named color             | ~8      | 13-byte output, one exact-length allocation                                                       |
| `Style.paint` — bold+italic+fg+bg       | ~14     | 20-byte combined SGR                                                                              |
| `Style.paint` — truecolor RGB           | ~30     | 24-byte output, three channels via the digit-pair table                                           |
| `Painter.paint` — RGB downgraded to 256 | ~8      | quantization plus paint; a held style's downgrade hoists out of the caller's loop                 |
| `Painter.paint` — RGB downgraded to 16  | ~8      | adds the comptime 256→16 table read on top of the 256 quantizer                                   |
| `Painter.paint` — disabled (`NONE`)     | ~0      | short-circuits before SGR work; this benchmark loop optimizes the plain copy away                 |
| `Style.paint_into` — fresh String sink  | ~25     | includes constructing the sink each call; the render itself allocates nothing                     |
| `ColorLevel.resolve` — changing signals | ~3      | the full ladder of String compares when a signal differs every call — the honest per-call ceiling |
| `strip_escapes` — short painted input   | ~41     | 22 bytes to 5                                                                                     |
| `strip_escapes` — long line with OSC-8  | ~170    | 129 bytes to 63 across eight sequences                                                            |
| `visible_width` — styled UTF-8          | ~22     | zero allocation, code-point counting                                                              |

Resolution is pure — no `getenv`, no `isatty`, no syscalls — so the old three-digit detection cost (~190 ns of environment walking) left the library; what remains has three tiers. Signals that change every call: ~3 ns in the suite (~1.5 ns in an isolated binary — code layout dominates at this scale), the row above. Signals held in variables: the optimizer proves the call loop-invariant and removes it — measured ~0 before the benchmark was hardened against hoisting. Signals known at compile time: `comptime` evaluation bakes the tier into the binary and the cost is exactly zero (.probe/probe_comptime_resolve.mojo). The application's own signal gathering (`getenv`, `isatty`) happens outside the library, once at startup, under its control.

Two vectorization "improvements" were tried and measured slower, so the scalar forms stay: extracting the first matching lane after a SIMD hit (real SGR text puts the next `ESC` in a chunk's first bytes, and the scalar re-scan exits immediately) and hand-written 16-wide code-point counting (the plain counting loop already auto-vectorizes). Details in `.probe/SYNTAX.md`, finding 15.

---

## Against the Retired Prototype

Baseline figures were recorded from the retired prototype before its removal, measured on the same machine against Mojo `1.0.0b3.dev2026061706` — an older nightly and a different day, so treat deltas as indicative rather than exact. This table is the baseline's archival record; the prototype is not reproducible from this repository.

| Path               | Prototype | 0.3.0 | Delta    |
| ------------------ | --------- | ----- | -------- |
| named paint        | 47        | ~8    | **5.9x** |
| combined paint     | 53        | ~14   | **3.8x** |
| truecolor paint    | 81        | ~30   | **2.7x** |
| strip, short input | 42        | ~41   | ~1.0x    |

The prototype's "sugar call, color disabled" row has no successor: per-call environment-probing sugar was removed outright when the library went environment-free — the comparable modern cost is `Painter.paint` at `NONE`, which rounds to zero.

Capability detection is deliberately absent from this table: the prototype's published 45 ns measured only the `NO_COLOR` short-circuit (its benchmark set `NO_COLOR=1` globally) — and environment probing has since left the library entirely, so no comparable path exists anymore.

This release also renders strictly more per call than the prototype did: `Painter.paint` quantizes to the destination's tier, `strip_escapes` handles OSC and plain escape sequences, and `visible_width` counts code points instead of bytes.

---

## What makes it fast

| Technique                                                                                                                                                                         | Where                                    |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| One-pass SGR emission into a comptime-bounded stack buffer — the same pass sizes and renders, so the length that reaches the allocator can never disagree with the bytes          | `style.mojo` render core                 |
| `paint` bulk-copies stack + text + reset into its single exact-length `String(unsafe_uninit_length=)` allocation — zero validation, zero growth                                   | `Style.paint`                            |
| Zero-allocation streaming: the open sequence stays on the stack behind a `StringSlice` view                                                                                       | `Style.paint_into`, `Painter.paint_into` |
| `@always_inline` render chain end to end — a compile-time-constant style (every sugar method) folds emission into a few byte stores; a held style hoists out of the caller's loop | `style.mojo`, `painter.mojo`             |
| No `raises` anywhere on the paint chain — no unwinding machinery                                                                                                                  | whole render path (.probe/SYNTAX.md)     |
| Two-digit lookup table for SGR parameters                                                                                                                                         | `_internal/decimal.mojo`                 |
| comptime-built 256→16 nearest-color table — the decode-and-search runs in the compile-time interpreter; runtime is one rodata read                                                | `_internal/quantize.mojo`                |
| 16-wide SIMD scan for `ESC` on escape-free runs                                                                                                                                   | `visible.mojo`                           |
| Disabled and empty paths return before touching SGR machinery; `paint_into` streams through without allocation, while `paint` still returns a plain `String` copy                 | `Painter.paint` at `NONE`, empty `Style` |
| One-byte `Painter` — capability travels in a register                                                                                                                             | every capability-aware call              |

---

## Reproducing

```bash
pixi run benchmark
```

Nothing in the benchmark suite touches the process environment — every input is held explicitly, the same purity contract as the library itself. `Style`/`Painter` benches inject levels; the resolve bench holds its signal strings and alternates only the TTY flag so the pure call cannot hoist out of the loop.
