from color import Color, ColorLevel, Painter, Style, strip_escapes


def main() raises:
    var painter = Painter.from_level(ColorLevel.ANSI16)
    var output = painter.paint(Style().foreground(Color.RED).bold(), "ok")
    if strip_escapes(output) != "ok":
        raise Error("installed color package failed its smoke test")

