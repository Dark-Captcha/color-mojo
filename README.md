# color

Typed ANSI color for Mojo — styling intent in, the right bytes out, wherever the text lands. Full escapes on a capable terminal, the nearest approximation on a lesser one, plain text everywhere else. And never a hidden read: the library is a pure function of signals your application supplies — no environment access, no global state, no surprises inside someone else's process.

```mojo
from color import Painter, Style, Color

def main() raises:
    # Resolve once from signals your app gathered (env, config, flags),
    # then paint everywhere. The library itself never probes anything.
    var painter = Painter.resolve(is_tty=True, term="xterm-256color")
    print(painter.green("ok"), painter.bright_yellow("warn"))

    var accent = Style().foreground(Color.from_hex("#ff6400")).bold()
    print(painter.paint(accent, "color-mojo"))      # truecolor, 256, 16, or plain —
                                                    # whatever the tier renders
```

---

## Why this library

| Guarantee              | Meaning                                                                                                                                                                                                                       |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pure by construction   | No environment reads, no globals, no TTY probes — `ColorLevel.resolve` is a pure function of explicit signals, deterministic and even comptime-evaluable                                                                      |
| Automatic reset        | Every paint is self-closing — style bleed is unrepresentable                                                                                                                                                                  |
| Capability correctness | Resolution honors the conventions (`no_color` > force flags — `0`/`false` disable > `clicolor=0` > TTY > `term=dumb` veto > `force_color` 1/2/3 floors > `colorterm` > `term`); colors downgrade RGB → 256 → 16, never vanish |
| Text truth             | `strip_escapes` and `visible_width` always agree with what `paint` produced                                                                                                                                                   |
| Cost discipline        | One exact-length allocation per styled `paint` (~8 ns named); zero allocation for `paint_into`; disabled rendering skips SGR work (`paint` returns a plain copy); no `raises` on the paint chain                              |

Full contracts, non-goals, and the system map: [ARCHITECTURE.md](ARCHITECTURE.md). Numbers: [PERF.md](PERF.md). Byte-level authorities: [references/README.md](references/README.md).

---

## Wiring real signals

The application owns its sources — that is the point. For a classic terminal program:

```mojo
from std.os import getenv, isatty

var painter = Painter.resolve(
    is_tty=isatty(1),
    no_color=getenv("NO_COLOR"),
    force_color=getenv("FORCE_COLOR"),
    clicolor=getenv("CLICOLOR"),
    clicolor_force=getenv("CLICOLOR_FORCE"),
    colorterm=getenv("COLORTERM"),
    term=getenv("TERM"),
)
```

`ColorLevel.resolve` is the same ladder when you want the tier itself — `Painter.resolve` is `from_level` over it, one call instead of two.

Resolve once per destination at startup (stdout and stderr can disagree) and keep the one-byte `Painter`. A config file, a `--color=never` flag, or a test harness feeds the same resolver — or skips it entirely with `Painter.plain()` / `Painter.from_level(ColorLevel.TRUECOLOR)`.

---

## Composition: wrap whole, or concatenate parts

A paint is atomic — open, text, reset. Wrapping an entire painted fragment works; embedding one inside a longer paint ends the outer style at the inner reset.

```mojo
print(p.bold(p.red("FATAL")))                                   # right: whole-span wrap
print(p.dim("[") + p.green("PASS") + p.dim("]"))                # right: concatenation
print(p.red("start " + p.bold("mid") + " end"))                 # wrong: "end" is not red
```

---

## The surface — seven names

| Name                  | Role                                                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------------------------------- |
| `Color`               | 16 named constants, `ansi256(index)`, `rgb(*, red, green, blue)`, `from_hex(text)`, `downgrade_to(level)`           |
| `Attribute`           | `BOLD` … `STRIKETHROUGH` — combine with `\|`                                                                        |
| `Style`               | Fluent builder; `paint(text)`, `paint_into(writer, text)` — verbatim                                                |
| `Painter`             | `plain()`, `from_level(level)`, `resolve(*, is_tty, …)`; capability-honest `paint` / `paint_into`; 24 sugar methods |
| `ColorLevel`          | `NONE < ANSI16 < ANSI256 < TRUECOLOR`; pure `resolve(*, is_tty, no_color, …)` turns signals into a tier             |
| `strip_escapes(text)` | The text a reader actually sees (CSI, OSC, DCS/SOS/PM/APC strings, plain escapes)                                   |
| `visible_width(text)` | Code points outside escapes — layout truth                                                                          |

`Style` declares WHAT; `Painter` knows WHERE; the application decides FROM WHAT. Tests inject `Painter.from_level(...)` and get byte-deterministic output.

---

## Writing into your own sink

`Writer` needs one method. Any byte buffer conforms in five lines:

```mojo
struct ByteSink(Writer):
    var storage: List[UInt8]
    def __init__(out self):
        self.storage = List[UInt8]()
    def write_string(mut self, string: StringSlice):
        self.storage.extend(string.as_bytes())

painter.paint_into(sink, style, "ERROR")    # streams; nothing is allocated
```

---

## Install

Requires Mojo `1.0.0b3` or later. A tested modular-community recipe is prepared in `conda.recipe/`; until it can target a stable `1.0.0b3` compiler and is accepted by the channel, vendor the `color/` package directory or add this repository as a source dependency; then:

```mojo
from color import Painter, Style, Color
```

Supported Pixi targets are `linux-64`, `linux-aarch64`, and `osx-arm64`.
Windows users run through WSL with a compatible Linux distribution; native
Windows and Intel macOS are not listed until the upstream `mojo` package exists
for those targets.

Development: `pixi run test`, `pixi run example`, `pixi run benchmark`, `pixi run format`.

---

## License

Apache-2.0 WITH LLVM-exception — the same terms as Mojo itself.
