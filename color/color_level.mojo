# ColorLevel — the color capability tier of an output destination, plus the
# pure resolver that interprets the conventional signals into a tier. Higher
# tiers render everything lower tiers can; comparisons express that ordering
# directly.
#
# This library never reads the process environment. A library-side getenv
# couples every caller to ambient global state — it can contradict the host
# application's own configuration, and setenv-driven tests race in threaded
# programs. `resolve` is instead a pure function of explicitly passed
# signals: the application gathers NO_COLOR and friends plus the TTY fact
# however it wishes (std.os.getenv / std.os.isatty, a config file, CLI
# flags) and hands over the values. Same inputs, same tier — deterministic,
# unit-testable without touching the process, and comptime-evaluable for
# fully static configuration (.probe/probe_comptime_resolve.mojo).
#
# Resolution order (references/README.md, consequence #9): `no_color` always
# wins; `force_color` "0" or "false" explicitly disables; `force_color` /
# `clicolor_force` set to anything else force at least ANSI16 and skip the
# TTY gate; without a force flag, `clicolor` "0" disables and a non-TTY
# destination gets NONE; `term` "dumb" vetoes everything else — its contract
# is no escapes; numeric `force_color` values raise the floor (1/2/3 ->
# ANSI16/ANSI256/TRUECOLOR — supports-color semantics: a floor, never a
# ceiling); `colorterm` announces truecolor; `term` announces 256-color.
# Authorities: no-color.org, the CLICOLOR convention ("force only when not
# 0"; CLICOLOR=0 means no color), the FORCE_COLOR lineage from
# Node/supports-color, and the TERM lineage in RFC 1091 / RFC 1572.


struct ColorLevel(Comparable, Copyable, Movable, TrivialRegisterPassable):
    """Capability tier of an output destination: `NONE`, `ANSI16`, `ANSI256`,
    or `TRUECOLOR`. Ordered — `ColorLevel.ANSI256 > ColorLevel.ANSI16` reads
    as "renders strictly more"."""

    var _tier: UInt8

    @always_inline
    def __init__(out self, *, tier: UInt8):
        self._tier = tier

    # --- Resolution -----------------------------------------------------------

    @staticmethod
    def resolve(
        *,
        is_tty: Bool,
        no_color: String = "",
        force_color: String = "",
        clicolor: String = "",
        clicolor_force: String = "",
        colorterm: String = "",
        term: String = "",
    ) -> ColorLevel:
        """The capability tier implied by the conventional signals — a pure
        function. The caller supplies each value (an empty string reads as
        unset) and the destination's TTY fact; nothing here consults the
        process. Signals carry their conventional environment names."""
        if no_color.byte_length() > 0:
            return ColorLevel.NONE

        if force_color == "0" or force_color == "false":
            # The explicit disable values of the FORCE_COLOR convention.
            return ColorLevel.NONE
        var forced = _is_forcing(force_color) or _is_forcing(clicolor_force)
        if not forced:
            if clicolor == "0":
                # CLICOLOR's explicit off switch — only a force flag
                # outranks it.
                return ColorLevel.NONE
            if not is_tty:
                return ColorLevel.NONE

        if term == "dumb":
            # A dumb terminal's contract is no escapes — nothing outranks
            # it, not forcing and not an inherited colorterm.
            return ColorLevel.NONE

        # Numeric force_color values raise the floor, never lower the
        # ceiling — supports-color semantics: a richer announcement wins.
        var floor = ColorLevel.NONE
        if forced:
            floor = ColorLevel.ANSI16
        if force_color == "2":
            floor = ColorLevel.ANSI256
        elif force_color == "3":
            floor = ColorLevel.TRUECOLOR

        if colorterm == "truecolor" or colorterm == "24bit":
            return ColorLevel.TRUECOLOR

        var announced = ColorLevel.NONE
        if term.endswith("256color"):
            announced = ColorLevel.ANSI256
        elif term.byte_length() > 0:
            announced = ColorLevel.ANSI16
        return announced if announced >= floor else floor

    # --- Inspection -----------------------------------------------------------

    @always_inline
    def is_enabled(self) -> Bool:
        """True when any color is supported — the tier is above `NONE`."""
        return self._tier > UInt8(0)

    # --- Comparable -----------------------------------------------------------

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


# --- Private helpers -----------------------------------------------------------


@always_inline
def _is_forcing(value: String) -> Bool:
    """True when a force flag is set to anything other than the conventional
    off value "0" (CLICOLOR spec: force only when not 0)."""
    return value.byte_length() > 0 and value != "0"
