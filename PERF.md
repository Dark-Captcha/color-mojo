# Performance — color-mojo

> **Version:** 0.1.0 | **Updated:** 2026-07-02

Hot-path latency, measured by `pixi run benchmark` (N = 200,000 per path, median of three runs, x86-64 Linux, Mojo `1.0.0b3.dev2026070123`).

---

## Current

| Path                                    | ns/call | Notes                                                                                                  |
| --------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------ |
| `Style.paint` — named color             | ~25     | 13-byte output, one exact-length allocation                                                            |
| `Style.paint` — bold+italic+fg+bg       | ~33     | 20-byte combined SGR                                                                                   |
| `Style.paint` — truecolor RGB           | ~59     | 24-byte output, three channels via the digit-pair table                                                |
| `Painter.paint` — RGB downgraded to 256 | ~30     | quantization plus paint, cheaper than the prototype's plain named paint                                |
| `Painter.paint` — disabled (`NONE`)     | ~0      | short-circuits; the benchmark loop optimizes away                                                      |
| `Style.paint_into` — fresh String sink  | ~38     | includes constructing the sink each call                                                               |
| `red(text)` under `NO_COLOR`            | ~40     | the sugar's shortest disable path: one `getenv`, pass through                                          |
| `Painter.detect` — forced ladder        | ~168    | four `getenv` walks plus TERM parsing; the TTY probe cannot run deterministically under a piped runner |
| `strip_escapes` — short painted input   | ~34     | 16 bytes to 5                                                                                          |
| `strip_escapes` — long line with OSC-8  | ~142    | 129 bytes to 63 across seven sequences                                                                 |
| `visible_width` — styled UTF-8          | ~20     | zero allocation, code-point counting                                                                   |

Detection is the one three-digit number — which is exactly why `Painter.detect` runs once at startup and the one-byte `Painter` travels everywhere else.

---

## Against the Retired Prototype

Baseline figures were recorded from the retired prototype before its removal, measured on the same machine against Mojo `1.0.0b3.dev2026061706` — an older nightly, so treat deltas as indicative rather than exact. This table is the baseline's archival record; the prototype is not reproducible from this repository.

| Path                       | Prototype | 0.1.0 | Delta    |
| -------------------------- | --------- | ----- | -------- |
| named paint                | 47        | ~25   | **1.9x** |
| combined paint             | 53        | ~33   | **1.6x** |
| truecolor paint            | 81        | ~59   | **1.4x** |
| sugar call, color disabled | 45        | ~40   | ~1.1x    |
| strip, short input         | 42        | ~34   | ~1.2x    |

Capability detection is deliberately absent from this table: the prototype's published 45 ns measured only the `NO_COLOR` short-circuit (its benchmark set `NO_COLOR=1` globally), so it has no valid comparison against the honestly measured forced ladder above.

This release also renders strictly more per call than the prototype did: `Painter.paint` quantizes to the destination's tier, `strip_escapes` handles OSC and plain escape sequences, and `visible_width` counts code points instead of bytes.

---

## What makes it fast

| Technique                                                                                                                     | Where                                    |
| ----------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| Exact-length precompute, then `String(unsafe_uninit_length=)` fill-in-place — one allocation, zero copies, no validation pass | `Style.paint`, `strip_escapes`           |
| No `raises` anywhere on the paint chain — no unwinding machinery                                                              | whole render path (.probe/SYNTAX.md)     |
| Two-digit lookup table for SGR parameters                                                                                     | `_internal/decimal.mojo`                 |
| `pop_count` for attribute sizing — one instruction, no loop                                                                   | `style.mojo` parameter-length pass       |
| 16-wide SIMD scan for `ESC` on escape-free runs                                                                               | `visible.mojo`                           |
| Disabled paths return before touching any machinery                                                                           | `Painter.paint` at `NONE`, empty `Style` |
| One-byte `Painter` — capability travels in a register                                                                         | every capability-aware call              |

---

## Reproducing

```bash
pixi run benchmark
```

Every environment-sensitive bench sets its own complete environment context immediately before measuring; `Style`/`Painter` benches inject levels and never consult the environment.
