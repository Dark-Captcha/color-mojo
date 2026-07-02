# color

Typed ANSI color for Mojo — styling intent in, the right bytes out, wherever the text lands. Full escapes on a capable terminal, the nearest approximation on a lesser one, plain text in pipes, files, CI logs, and under `NO_COLOR`.

```mojo
from color import Painter, Style, Color, red, bold

def main() raises:
    print(red("error: config not found"))          # plain when piped — automatically

    var painter = Painter.detect()                  # probe once, paint everywhere
    print(painter.green("ok"), painter.bright_yellow("warn"))

    var accent = Style().foreground(Color.from_hex("#ff6400")).bold()
    print(painter.paint(accent, "color-mojo"))      # truecolor, 256, 16, or plain —
                                                    # whatever the terminal renders
```

---

## Why this library

| Guarantee              | Meaning                                                                                                                                                           |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Automatic reset        | Every paint is self-closing — style bleed is unrepresentable                                                                                                      |
| Capability correctness | Detection per destination (`NO_COLOR` > force flags, `0` disables > TTY > `TERM=dumb` veto > `COLORTERM` > `TERM`); colors downgrade RGB → 256 → 16, never vanish |
| Text truth             | `strip_escapes` and `visible_width` always agree with what `paint` produced                                                                                       |
| Cost discipline        | One exact-length allocation per paint (~29 ns named); zero when styling is off; no `raises` on the paint chain                                                    |

Full contracts, non-goals, and the system map: [ARCHITECTURE.md](ARCHITECTURE.md). Numbers: [PERF.md](PERF.md). Byte-level authorities: [references/README.md](references/README.md).

---

## Composition: wrap whole, or concatenate parts

A paint is atomic — open, text, reset. Wrapping an entire painted fragment works; embedding one inside a longer paint ends the outer style at the inner reset.

```mojo
var p = Painter.detect()
print(bold(red("FATAL")))                                       # right: whole-span wrap
print(p.dim("[") + p.green("PASS") + p.dim("]"))                # right: concatenation
print(p.red("start " + p.bold("mid") + " end"))                 # wrong: "end" is not red
```

---

## The surface — twenty names

| Name                                      | Role                                                                                                       |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `Color`                                   | 16 named constants, `ansi256(index)`, `rgb(*, red, green, blue)`, `from_hex(text)`, `downgrade_to(level)`  |
| `Attribute`                               | `BOLD` … `STRIKETHROUGH` — combine with `\|`                                                               |
| `Style`                                   | Fluent builder; `paint(text)`, `paint_into(writer, text)` — verbatim                                       |
| `Painter`                                 | `detect(fd=1)`, `plain()`, `from_level(level)`; capability-honest `paint` / `paint_into`; 24 sugar methods |
| `ColorLevel`                              | `NONE < ANSI16 < ANSI256 < TRUECOLOR`                                                                      |
| `strip_escapes(text)`                     | The text a reader actually sees (CSI, OSC, plain escape sequences)                                         |
| `visible_width(text)`                     | Code points outside escapes — layout truth                                                                 |
| `red` … `white`, `bold` … `strikethrough` | Thirteen one-liners; each probes the destination per call                                                  |

`Style` declares WHAT; `Painter` knows WHERE. Tests inject `Painter.from_level(...)` and get byte-deterministic output.

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

painter.paint_into(sink, style, "ERROR")    # the text streams through unbuffered
```

---

## Install

Requires Mojo `1.0.0b3` or later. Until a package is published, vendor the `color/` package directory or add this repository as a source dependency; then:

```mojo
from color import Painter, Style, Color
```

Development: `pixi run test`, `pixi run example`, `pixi run benchmark`, `pixi run format`.

---

## License

Apache-2.0 WITH LLVM-exception — the same terms as Mojo itself.
