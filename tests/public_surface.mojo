# tests/public_surface.mojo — black-box public API gate. This file imports
# only the package root, so it fails if any of the seven documented names stop
# resolving through `from color import ...`.

from color import (
    Attribute,
    Color,
    ColorLevel,
    Painter,
    Style,
    strip_escapes,
    visible_width,
)


def _assert(condition: Bool, message: String) raises:
    if not condition:
        raise Error("assertion failed: " + message)


def main() raises:
    var plain = Painter.plain()
    _assert(plain.red("x") == "x", "Painter re-export works")
    _assert(not plain.is_enabled(), "ColorLevel reachable through Painter")

    var forced = Painter.from_level(ColorLevel.TRUECOLOR)
    var style = Style().foreground(Color.rgb(red=1, green=2, blue=3)).bold()
    _assert(
        forced.paint(style, "rgb") == "\x1b[1;38;2;1;2;3mrgb\x1b[0m",
        "Style, Color, and Painter compose from package root",
    )

    var combined = Attribute.BOLD | Attribute.UNDERLINE
    _assert(combined.contains(Attribute.BOLD), "Attribute re-export works")
    _assert(
        forced.paint(Style().attribute(combined), "x") == "\x1b[1;4mx\x1b[0m",
        "Attribute values render through public Style",
    )

    var painted = forced.green("ok")
    _assert(strip_escapes(painted) == "ok", "strip_escapes re-export works")
    _assert(visible_width(painted) == 2, "visible_width re-export works")

    print("public surface passed")
