# examples/basic_usage.mojo — a tour of the public surface.
# Run: pixi run example. Painted output honors your terminal: piped output
# stays plain, NO_COLOR is respected, and lesser terminals get the nearest
# renderable color instead of nothing.

from color import (
    Color,
    ColorLevel,
    Painter,
    Style,
    bold,
    red,
    strip_escapes,
    visible_width,
)


def main() raises:
    print("== minute one ==")
    print(red("error: config not found"), bold("(fatal)"))

    print("")
    print("== the painter: probe once, paint everywhere ==")
    var painter = Painter.detect()
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
