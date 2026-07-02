# Painter — the capability handle: knows WHERE text lands and what that
# destination can render. One byte, freely copyable, no global state — hold
# one per destination (stdout and stderr can disagree). Style declares WHAT;
# Painter downgrades the declaration to the destination's tier and paints.
# At NONE everything renders as plain text — attributes included.
#
# The module-level functions at the bottom are minute-one sugar: each call
# probes the environment once (`Painter.detect()`), which is correct and
# convenient for scripts. Hot paths and libraries hold a Painter instead.

from color.color import Color
from color.color_level import ColorLevel, _detect_level
from color.style import Style


struct Painter(Copyable, Movable, TrivialRegisterPassable):
    """Capability-honest renderer for one destination. Build with `detect`
    (environment + TTY probe), `plain` (never any escapes), or `from_level`
    (injected tier — tests, configuration, forced modes)."""

    var _level: ColorLevel

    @always_inline
    def __init__(out self, *, level: ColorLevel):
        self._level = level

    # --- Constructors ---------------------------------------------------------

    @staticmethod
    def detect(fd: Int = 1) -> Painter:
        """Probe the capability of file descriptor `fd` — default 1, stdout,
        where `print` goes. Probe once at startup and keep the Painter."""
        return Painter(level=_detect_level(fd))

    @staticmethod
    @always_inline
    def plain() -> Painter:
        """A Painter that never emits an escape byte."""
        return Painter(level=ColorLevel.NONE)

    @staticmethod
    @always_inline
    def from_level(level: ColorLevel) -> Painter:
        """A Painter at an explicit capability tier — byte-deterministic
        rendering for tests and configuration-driven forcing."""
        return Painter(level=level)

    # --- Inspection -----------------------------------------------------------

    @always_inline
    def level(self) -> ColorLevel:
        return self._level

    @always_inline
    def is_enabled(self) -> Bool:
        return self._level.is_enabled()

    # --- Rendering ------------------------------------------------------------

    def paint(self, style: Style, text: String) -> String:
        """Render `style` downgraded to this destination's tier. Plain text
        at `NONE`; colors walk down the ladder, never disappear."""
        if not self._level.is_enabled():
            return text.copy()
        return self._downgraded(style).paint(text)

    def paint_into[W: Writer](self, mut writer: W, style: Style, text: String):
        """`paint`, streamed into `writer` — the text body is never copied
        into an intermediate String."""
        if not self._level.is_enabled():
            writer.write(text)
            return
        self._downgraded(style).paint_into(writer, text)

    def _downgraded(self, style: Style) -> Style:
        var foreground: Optional[Color] = None
        if style._foreground:
            foreground = Optional[Color](
                style._foreground.value().downgrade_to(self._level)
            )
        var background: Optional[Color] = None
        if style._background:
            background = Optional[Color](
                style._background.value().downgrade_to(self._level)
            )
        var next = Style(
            foreground=foreground,
            background=background,
            attributes=style._attributes,
        )
        return next^

    # --- Color sugar (the sixteen) --------------------------------------------

    @always_inline
    def black(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BLACK), text)

    @always_inline
    def red(self, text: String) -> String:
        return self.paint(Style().foreground(Color.RED), text)

    @always_inline
    def green(self, text: String) -> String:
        return self.paint(Style().foreground(Color.GREEN), text)

    @always_inline
    def yellow(self, text: String) -> String:
        return self.paint(Style().foreground(Color.YELLOW), text)

    @always_inline
    def blue(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BLUE), text)

    @always_inline
    def magenta(self, text: String) -> String:
        return self.paint(Style().foreground(Color.MAGENTA), text)

    @always_inline
    def cyan(self, text: String) -> String:
        return self.paint(Style().foreground(Color.CYAN), text)

    @always_inline
    def white(self, text: String) -> String:
        return self.paint(Style().foreground(Color.WHITE), text)

    @always_inline
    def bright_black(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BRIGHT_BLACK), text)

    @always_inline
    def bright_red(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BRIGHT_RED), text)

    @always_inline
    def bright_green(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BRIGHT_GREEN), text)

    @always_inline
    def bright_yellow(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BRIGHT_YELLOW), text)

    @always_inline
    def bright_blue(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BRIGHT_BLUE), text)

    @always_inline
    def bright_magenta(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BRIGHT_MAGENTA), text)

    @always_inline
    def bright_cyan(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BRIGHT_CYAN), text)

    @always_inline
    def bright_white(self, text: String) -> String:
        return self.paint(Style().foreground(Color.BRIGHT_WHITE), text)

    # --- Attribute sugar (the eight) ------------------------------------------

    @always_inline
    def bold(self, text: String) -> String:
        return self.paint(Style().bold(), text)

    @always_inline
    def dim(self, text: String) -> String:
        return self.paint(Style().dim(), text)

    @always_inline
    def italic(self, text: String) -> String:
        return self.paint(Style().italic(), text)

    @always_inline
    def underline(self, text: String) -> String:
        return self.paint(Style().underline(), text)

    @always_inline
    def blink(self, text: String) -> String:
        return self.paint(Style().blink(), text)

    @always_inline
    def reverse(self, text: String) -> String:
        return self.paint(Style().reverse(), text)

    @always_inline
    def hidden(self, text: String) -> String:
        return self.paint(Style().hidden(), text)

    @always_inline
    def strikethrough(self, text: String) -> String:
        return self.paint(Style().strikethrough(), text)


# --- Minute-one sugar -----------------------------------------------------------
#
# Each function probes the destination per call — correct everywhere,
# convenient for scripts, and one environment probe of cost. Libraries and
# hot paths hold a Painter.


def black(text: String) -> String:
    return Painter.detect().black(text)


def red(text: String) -> String:
    return Painter.detect().red(text)


def green(text: String) -> String:
    return Painter.detect().green(text)


def yellow(text: String) -> String:
    return Painter.detect().yellow(text)


def blue(text: String) -> String:
    return Painter.detect().blue(text)


def magenta(text: String) -> String:
    return Painter.detect().magenta(text)


def cyan(text: String) -> String:
    return Painter.detect().cyan(text)


def white(text: String) -> String:
    return Painter.detect().white(text)


def bold(text: String) -> String:
    return Painter.detect().bold(text)


def dim(text: String) -> String:
    return Painter.detect().dim(text)


def italic(text: String) -> String:
    return Painter.detect().italic(text)


def underline(text: String) -> String:
    return Painter.detect().underline(text)


def strikethrough(text: String) -> String:
    return Painter.detect().strikethrough(text)
