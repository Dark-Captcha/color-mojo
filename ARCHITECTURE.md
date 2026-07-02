# Architecture — color-mojo

> **Version:** 0.1.0 | **Updated:** 2026-07-02

Purpose, binding contracts, scope, public surface, and system map of color-mojo — the criteria every structural decision in this library is judged against.

---

| #   | Section                           |
| --- | --------------------------------- |
| 1   | [Purpose](#purpose)               |
| 2   | [Contracts](#contracts)           |
| 3   | [Audience](#audience)             |
| 4   | [Scope](#scope)                   |
| 5   | [Non-Goals](#non-goals)           |
| 6   | [Public Surface](#public-surface) |
| 7   | [Conventions](#conventions)       |
| 8   | [Standards](#standards)           |
| 9   | [System Map](#system-map)         |

---

## Purpose

color-mojo turns styling intent into the right bytes for wherever text actually lands.

A program declares meaning — "this is an error: red, bold." The library decides what that becomes: full escapes on a capable terminal, the nearest approximation on a limited one, plain text in a pipe, a file, a CI log, or for a user who asked for no color. The caller states intent once; the library owns the wire format.

Every language ecosystem grows exactly one of these; the standard library never provides it. Everything built on top inherits its correctness — or its bugs. Solving terminal color correctly once, at the bottom of the stack, fixes it for every tool above.

---

## Contracts

Everything the library does serves one of these four contracts. Anything that serves none of them does not belong.

| #   | Contract               | Obligation                                                                                                                                                                                                                                                           |
| --- | ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Typed styling          | No one hand-writes escape strings. Colors, attributes, and styles are values — invalid sequences are unrepresentable, valid ones compose.                                                                                                                            |
| 2   | Capability correctness | Never emit what the destination cannot render. Detection is explicit and standards-honoring; colors degrade down the capability ladder instead of disappearing or corrupting output. Styled bytes belong only on terminals — everywhere else, text stays plain text. |
| 3   | Round-trip honesty     | Styled text is still text. Anything the library produces can be stripped back to plain text and measured for its visible width, so layout code, log processors, and tests always know what the reader actually sees.                                                 |
| 4   | Cost discipline        | Styling sits inside the print path of every adopting program, so it must be cheap enough to live there: probe the environment once, render with minimal allocation, add nothing to the cost of text that ends up unstyled.                                           |

**The purpose test:** every proposed feature must name the contract it serves. A feature that names none is out of scope, regardless of how useful it sounds.

---

## Audience

| Priority  | Audience                                                   | Requirement                                                                         |
| --------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Primary   | Libraries — logging frameworks, CLI toolkits, test runners | Style text thousands of times per second; tolerate no hidden costs, no global state |
| Secondary | Application authors                                        | One obvious line that just works                                                    |

Both audiences ride the same engine. Ergonomics is a thin layer over the primary API — never a second code path.

---

## Scope

What users want reduces to one sentence: the color, with automatic reset, and no missing feature versus any peer library. That sentence expands into three binding guarantees, a feature surface, and a deferred list.

### Guarantees

| Guarantee              | Meaning                                                                                                                                                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Automatic reset        | Every paint is self-closing: open, text, reset. Style bleed into subsequent output is impossible by construction — no API exists to emit an unclosed style.                                                        |
| Flat composition       | A paint is atomic. Compose by styling fragments and concatenating them; embedding already-painted text inside another paint ends the outer style at the inner reset. This is documented behavior, not an accident. |
| Two layers, one engine | Module-level one-liner functions are sugar over the capability handle — identical behavior, identical bytes, no second code path.                                                                                  |
| Downgrade, not drop    | On a lesser terminal a color degrades to its nearest renderable ancestor — direct RGB to the 256-color palette to the named 16 — and to plain text only where no color is supported at all.                        |

### Feature Surface

| Area        | Committed                                                                                                                     |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Colors      | 16 named + bright variants, xterm-256 palette, 24-bit RGB, hex parsing (`#rrggbb`) — foreground and background                |
| Attributes  | Bold, dim, italic, underline, blink, reverse, hidden, strikethrough                                                           |
| Composition | Fluent, order-insensitive style builder; styles are plain values                                                              |
| Detection   | `NO_COLOR` > force flags (`0` disables, never forces) > TTY > `TERM=dumb` veto > `COLORTERM` > `TERM`, per destination        |
| Control     | Detect-once handle; injectable capability level for tests and forced modes                                                    |
| Rendering   | Single-allocation string paint; writer paint streams the text body unbuffered (one small fixed-size open-sequence allocation) |
| Text truth  | Escape stripping and visible-width measurement, always consistent with what paint produces                                    |

### Deferred

Parked for a future release — the design keeps the door open, the current surface excludes them.

| Deferred feature           | Reason                                                                                    |
| -------------------------- | ----------------------------------------------------------------------------------------- |
| Nesting-aware repaint      | Requires rescanning every input on every paint — violates cost discipline for a rare case |
| Gradient text              | Presentational sugar; pulls in color-interpolation policy                                 |
| Hyperlink emitting (OSC 8) | Serves no current contract; stripping already handles incoming links                      |
| Windows console support    | Platform scope is POSIX first                                                             |

---

## Non-Goals

| Excluded                | Reason                                                                     | Belongs to                          |
| ----------------------- | -------------------------------------------------------------------------- | ----------------------------------- |
| TUI framework           | No cursor movement, no layout — a different problem domain                 | A library that builds on this one   |
| Terminal database       | Capability detection is honest heuristics, not a terminfo reimplementation | terminfo / the terminal itself      |
| Unicode width authority | Visible width counts characters; wide-glyph typography is out of scope     | A dedicated width library (UAX #11) |
| Theme system            | Deciding that errors are red is application policy                         | The application                     |
| Alpha / transparency    | The terminal wire format carries color, not alpha                          | Compositing before the terminal     |

---

## Public Surface

Twenty names. Everything else lives under `_internal/` and is not part of the contract.

### Types

| Type         | Kind                              | Surface                                                                                                                                                                                   |
| ------------ | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ColorLevel` | 1-byte value, `Comparable`        | `NONE < ANSI16 < ANSI256 < TRUECOLOR`; `is_enabled()`                                                                                                                                     |
| `Color`      | 4-byte tagged value, `Comparable` | 16 named constants (`BLACK` … `BRIGHT_WHITE`); `ansi256(index)`, `rgb(*, red, green, blue)`, `from_hex(text) raises`; `downgrade_to(level)`                                               |
| `Attribute`  | 1-byte bitset, `Comparable`       | `NONE` + 8 constants (`BOLD` … `STRIKETHROUGH`); `__or__`, `__and__`, `contains`, `is_empty`                                                                                              |
| `Style`      | intent value, immutable builder   | `Style()` empty; `foreground`, `background`, `attribute` + 8 shortcuts; `is_empty`; `paint(text)`, `paint_into[W: Writer](writer, text)`                                                  |
| `Painter`    | 1-byte capability handle          | `detect(fd=1)`, `plain()`, `from_level(level)`; `level()`, `is_enabled()`; `paint(style, text)`, `paint_into[W: Writer](writer, style, text)`; 24 sugar methods (16 colors, 8 attributes) |

### Functions

| Function                                                              | Role                                                       |
| --------------------------------------------------------------------- | ---------------------------------------------------------- |
| `strip_escapes(text) -> String`                                       | Remove every recognized escape sequence                    |
| `visible_width(text) -> Int`                                          | Code points outside escapes — layout truth                 |
| `red`, `black`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white` | Minute-one sugar: `Painter.detect().<name>(text)` per call |
| `bold`, `dim`, `italic`, `underline`, `strikethrough`                 | Same, for the five everyday attributes                     |

`from_hex` is the single `raises` on the friendly path — validating parser at a boundary; parse hex constants once, at startup.

> Both open questions are resolved in `.probe/SYNTAX.md` (probed on the real toolchain, not assumed): the paint chain is `raises`-free — `String(unsafe_uninit_length=)` gives an exact-length, fill-in-place allocation, sound because only ASCII escape bytes and the caller's already-valid UTF-8 are assembled. `paint_into` emits through `Writer.write_string`; `String` is a conforming sink out of the box, and any byte buffer conforms via a five-line wrapper struct.

---

## Conventions

| Convention                       | Rule                                                                                                                                                                             |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Style declares, Painter destines | `Style` renders intent verbatim; `Painter` renders honestly for a destination. Capability logic exists nowhere else.                                                             |
| Automatic reset                  | Every paint is self-closing. Full-span nesting works (`bold(red(x))`); partial embedding ends the outer style — wrap whole, or concatenate parts.                                |
| Naming law                       | Full words only. A short form survives only when it is the domain's own lexicalized name: `rgb`, `ansi256`, `hex`, `fd`. Truncations (`attr`, `fg`, `strike`) do not exist here. |
| One file per public type         | Every public module is exactly its type's snake_case name; a reader guesses file contents with certainty.                                                                        |
| Downward imports only            | `painter` → `style` → `color`/`attribute` → `color_level`; everyone may use `_internal`; never a cycle, never sideways.                                                          |
| Keyword-only color channels      | `Color.rgb(*, red, green, blue)` — more than two same-typed arguments take keywords; the `rgb(b, g, r)` transposition bug is unrepresentable.                                    |
| Sugar tiers                      | Module level: 13 greatest hits. `Painter`: all 24. `Style`: everything expressible. Each tier is one line over the tier below — never a second engine.                           |

---

## Standards

Every byte this library emits or parses has a named authority. The vendored specification texts, the linked external standards, and the design consequences drawn from each live in [references/README.md](references/README.md). Module headers cite entries from that index rather than restating specification text.

---

## System Map

```text
color/
├── __init__.mojo          # re-exports only — the twenty public names
├── color_level.mojo       # ColorLevel + the detection ladder (private)
├── color.mojo             # Color: constants, ansi256, rgb, from_hex, downgrade_to
├── attribute.mojo         # Attribute bitset
├── style.mojo             # Style: builder + verbatim render
├── painter.mojo           # Painter + the 13 module-level sugar functions
├── visible.mojo           # strip_escapes + visible_width
└── _internal/
    ├── sgr.mojo           # ESC constants; attribute-bit to SGR-code table — single source
    ├── quantize.mojo      # RGB to 256 to 16 nearest-match math
    └── decimal.mojo       # integer to ASCII-decimal writer
```

Dependency direction — imports point down only:

```text
painter ──→ style ──→ color ──→ color_level
   │           │         │      attribute
   │           │         │           │
   └───────────┴─────────┴───────────┴──→ _internal/{sgr, quantize, decimal}

visible ──→ _internal/sgr only        # strips foreign text; touches no public type
```

| Module        | Holds                                    | May import                                     |
| ------------- | ---------------------------------------- | ---------------------------------------------- |
| `color_level` | `ColorLevel`, detection ladder           | `_internal` only                               |
| `attribute`   | `Attribute`                              | `_internal` only                               |
| `color`       | `Color`, hex parsing, downgrading        | `color_level`, `_internal`                     |
| `style`       | `Style`, verbatim rendering              | `color`, `attribute`, `_internal`              |
| `painter`     | `Painter`, module-level sugar            | `style`, `color`, `attribute`, `color_level`   |
| `visible`     | `strip_escapes`, `visible_width`         | `_internal/sgr` only — deliberately standalone |
| `_internal/*` | SGR table, quantization, decimal writing | nothing above `_internal`                      |

`visible` depending on no public type is a structural promise: integrators strip and measure foreign text without touching the color machinery.
