# ColorLevel — the color capability tier of an output destination, plus the
# environment ladder that detects it. Higher tiers render everything lower
# tiers can; comparisons express that ordering directly.
#
# Detection order (references/README.md, consequence #9): NO_COLOR always
# wins; FORCE_COLOR=0 explicitly disables; FORCE_COLOR / CLICOLOR_FORCE set
# to anything else force at least ANSI16 and skip the TTY gate; a non-TTY
# destination gets NONE; TERM="dumb" vetoes everything else — its contract
# is no escapes, so it is checked before COLORTERM; COLORTERM announces
# truecolor; TERM announces 256-color. Authorities: no-color.org, the
# CLICOLOR convention ("force only when not 0"), and the TERM lineage in
# RFC 1091 / RFC 1572.

from std.os import getenv, isatty


struct ColorLevel(Comparable, Copyable, Movable, TrivialRegisterPassable):
    """Capability tier of an output destination: `NONE`, `ANSI16`, `ANSI256`,
    or `TRUECOLOR`. Ordered — `ColorLevel.ANSI256 > ColorLevel.ANSI16` reads
    as "renders strictly more"."""

    var _tier: UInt8

    @always_inline
    def __init__(out self, *, tier: UInt8):
        self._tier = tier

    @always_inline
    def is_enabled(self) -> Bool:
        """True when any color is supported — the tier is above `NONE`."""
        return self._tier > UInt8(0)

    @always_inline
    def __eq__(self, other: ColorLevel) -> Bool:
        return self._tier == other._tier

    @always_inline
    def __ne__(self, other: ColorLevel) -> Bool:
        return self._tier != other._tier

    @always_inline
    def __lt__(self, other: ColorLevel) -> Bool:
        return self._tier < other._tier

    @always_inline
    def __le__(self, other: ColorLevel) -> Bool:
        return self._tier <= other._tier

    @always_inline
    def __gt__(self, other: ColorLevel) -> Bool:
        return self._tier > other._tier

    @always_inline
    def __ge__(self, other: ColorLevel) -> Bool:
        return self._tier >= other._tier

    comptime NONE: ColorLevel = ColorLevel(tier=UInt8(0))
    comptime ANSI16: ColorLevel = ColorLevel(tier=UInt8(1))
    comptime ANSI256: ColorLevel = ColorLevel(tier=UInt8(2))
    comptime TRUECOLOR: ColorLevel = ColorLevel(tier=UInt8(3))


# --- Detection (package-private; the public entry point is Painter.detect) --


def _detect_level(fd: Int) -> ColorLevel:
    """Resolve the capability of file descriptor `fd` from the environment.
    Deterministic given the environment — no caching, no global state."""
    if _has_environment("NO_COLOR"):
        return ColorLevel.NONE

    var force_color = getenv("FORCE_COLOR")
    if force_color == "0":
        # The explicit disable value of the FORCE_COLOR convention.
        return ColorLevel.NONE
    var forced = _is_forcing(force_color) or _is_forcing(
        getenv("CLICOLOR_FORCE")
    )
    if not forced and not isatty(fd):
        return ColorLevel.NONE

    var term = getenv("TERM")
    if term == "dumb":
        # A dumb terminal's contract is no escapes — nothing outranks it,
        # not forcing and not an inherited COLORTERM.
        return ColorLevel.NONE

    var colorterm = getenv("COLORTERM")
    if colorterm == "truecolor" or colorterm == "24bit":
        return ColorLevel.TRUECOLOR

    if term.endswith("256color"):
        return ColorLevel.ANSI256
    if term.byte_length() == 0:
        if forced:
            return ColorLevel.ANSI16
        return ColorLevel.NONE
    return ColorLevel.ANSI16


@always_inline
def _is_forcing(value: String) -> Bool:
    """True when a force flag is set to anything other than the conventional
    off value "0" (CLICOLOR spec: force only when not 0)."""
    return value.byte_length() > 0 and value != "0"


@always_inline
def _has_environment(name: String) -> Bool:
    return getenv(name).byte_length() > 0
