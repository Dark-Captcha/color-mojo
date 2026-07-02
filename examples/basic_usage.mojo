# examples/basic_usage.mojo — a tour of the public surface.
# Run: pixi run example. The library never reads the process environment:
# the application resolves a tier from signals it gathered itself
# (std.os.getenv / std.os.isatty, a config file, CLI flags) and hands the
# Painter that tier. This tour holds its signals as literals so it renders
# the same everywhere; README.md shows the real-environment wiring.

from color import (
    Color,
    ColorLevel,
    Painter,
    Style,
    strip_escapes,
    visible_width,
)


def main() raises:
    print("== resolve once, paint everywhere ==")
    var painter = Painter.resolve(
        is_tty=True, colorterm="truecolor", term="xterm-256color"
    )
    print(
        painter.green("ok"), painter.bright_yellow("warn"), painter.red("fail")
    )

    print("")
    print("== styles are values ==")
    var accent = Style().foreground(Color.from_hex("#ff6400")).bold()
    var path = Style().foreground(Color.CYAN).italic()
    print(
        painter.paint(accent, "color-mojo"),
        "reads",
        painter.paint(path, "/etc/app.toml"),
    )

    print("")
    print("== downgrade, not drop ==")
    var orange = Style().foreground(Color.rgb(red=255, green=100, blue=0))
    print(
        "truecolor:",
        Painter.from_level(ColorLevel.TRUECOLOR).paint(orange, "orange"),
    )
    print(
        "ansi256  :",
        Painter.from_level(ColorLevel.ANSI256).paint(orange, "orange"),
    )
    print(
        "ansi16   :",
        Painter.from_level(ColorLevel.ANSI16).paint(orange, "orange"),
    )
    print("plain    :", Painter.plain().paint(orange, "orange"))

    print("")
    print("== signals decide — no_color wins, force skips the TTY gate ==")
    var silenced = ColorLevel.resolve(
        is_tty=True, no_color="1", colorterm="truecolor", term="xterm"
    )
    var forced = ColorLevel.resolve(
        is_tty=False, clicolor_force="1", term="xterm"
    )
    print("no_color :", Painter.from_level(silenced).red("plain"))
    print("forced   :", Painter.from_level(forced).red("red in a pipe"))

    print("")
    print("== compose by concatenation, wrap whole or not at all ==")
    print(
        painter.dim("[") + painter.green("PASS") + painter.dim("]"),
        painter.bold("tests/visible"),
    )

    print("")
    print("== text truth ==")
    var painted = painter.paint(accent, "ALERT")
    print("painted      :", painted)
    print("stripped     :", strip_escapes(painted))
    print("visible width:", visible_width(painted))
