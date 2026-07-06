# Painter — the capability handle: knows WHERE text lands and what that
# destination can render. One byte, freely copyable, no global state — hold
# one per destination (stdout and stderr can disagree). Style declares WHAT;
# Painter downgrades the declaration to the destination's tier and paints.
# At NONE everything renders as plain text — attributes included.
#
# A Painter is built from a tier the application already holds: `plain()`,
# `from_level(level)`, or `resolve(...)` — `from_level` over
# `ColorLevel.resolve` in one call, for signals the application gathered.
# Nothing here reads the process environment.

from color.color import Color
from color.color_level import ColorLevel
from color.style import Style


struct Painter(Copyable, Movable, TrivialRegisterPassable):
    """Capability-honest renderer for one destination. Build with `plain`
    (never any escapes), `from_level` (an injected tier — configuration,
    tests, forced modes), or `resolve` (a tier from supplied signals)."""

    var _level: ColorLevel

    @doc_hidden
    @always_inline
    def __init__(out self, *, level: ColorLevel):
        self._level = level

    # --- Constructors ---------------------------------------------------------

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

    @staticmethod
    @always_inline
    def resolve(
        *,
        is_tty: Bool,
        no_color: String = "",
        force_color: String = "",
        clicolor: String = "",
        clicolor_force: String = "",
        colorterm: String = "",
        term: String = "",
    ) -> Painter:
        """`from_level(ColorLevel.resolve(...))` in one call — the startup
        line of a terminal application. Pure like everything here: the
        caller supplies the signals; nothing reads the process."""
        return Painter(
            level=ColorLevel.resolve(
                is_tty=is_tty,
                no_color=no_color,
                force_color=force_color,
                clicolor=clicolor,
                clicolor_force=clicolor_force,
                colorterm=colorterm,
                term=term,
            )
        )

    # --- Inspection -----------------------------------------------------------

    @always_inline
    def level(self) -> ColorLevel:
        return self._level

    @always_inline
    def is_enabled(self) -> Bool:
        return self._level.is_enabled()

    # --- Rendering ------------------------------------------------------------

    @always_inline
    def paint(self, style: Style, text: String) -> String:
        """Render `style` downgraded to this destination's tier. Plain text
        at `NONE`; colors walk down the ladder, never disappear."""
        if not self._level.is_enabled():
            return text.copy()
        if self._level == ColorLevel.TRUECOLOR:
            # downgrade_to is the identity at the top tier — skip the rebuild.
            return style.paint(text)
        return self._downgraded(style).paint(text)

    @always_inline
    def paint_into[W: Writer](self, mut writer: W, style: Style, text: String):
        """`paint`, streamed into `writer` — the text body is never copied
        into an intermediate String, and nothing is allocated."""
        if not self._level.is_enabled():
            writer.write(text)
            return
        if self._level == ColorLevel.TRUECOLOR:
            style.paint_into(writer, text)
            return
        self._downgraded(style).paint_into(writer, text)

    @always_inline
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
