# Color — one color value spanning the three ANSI color spaces, stored as a
# four-byte tagged union (tag + three payload bytes) so it travels in
# registers. The sixteen named colors are comptime constants and store their
# palette index 0..15 — never a raw SGR code; the wire encoding is a
# rendering concern. No alpha channel exists: the terminal wire format
# carries color only (references/README.md, consequence #7).
#
# Downgrading walks the capability ladder — direct RGB to the 256-color
# palette to the named sixteen — via _internal/quantize.

from color._internal.quantize import ansi256_to_named16, rgb_to_ansi256
from color.color_level import ColorLevel


comptime _KIND_NAMED: UInt8 = UInt8(0)
comptime _KIND_ANSI256: UInt8 = UInt8(1)
comptime _KIND_RGB: UInt8 = UInt8(2)


struct Color(Comparable, Copyable, Movable, TrivialRegisterPassable):
    """One color value: a named ANSI color, an xterm-256 index, or a 24-bit
    RGB triple. Build from the sixteen constants, `ansi256`, `rgb`, or
    `from_hex`; adapt to a destination with `downgrade_to`."""

    var _kind: UInt8
    var _a: UInt8
    var _b: UInt8
    var _c: UInt8

    @always_inline
    def __init__(out self, *, kind: UInt8, a: UInt8, b: UInt8, c: UInt8):
        self._kind = kind
        self._a = a
        self._b = b
        self._c = c

    # --- Constructors --------------------------------------------------------

    @staticmethod
    @always_inline
    def _named(index: UInt8) -> Color:
        """Palette index 0..15 — package-internal; the constants are the API."""
        return Color(kind=_KIND_NAMED, a=index, b=UInt8(0), c=UInt8(0))

    @staticmethod
    @always_inline
    def ansi256(index: UInt8) -> Color:
        """An xterm-256 palette index, 0..255."""
        return Color(kind=_KIND_ANSI256, a=index, b=UInt8(0), c=UInt8(0))

    @staticmethod
    @always_inline
    def rgb(*, red: UInt8, green: UInt8, blue: UInt8) -> Color:
        """A 24-bit RGB color. Channels are keyword-only so a transposed
        call order is unrepresentable."""
        return Color(kind=_KIND_RGB, a=red, b=green, c=blue)

    @staticmethod
    def from_hex(text: String) raises -> Color:
        """Parse `"#rrggbb"` or `"rrggbb"` (case-insensitive) into an RGB
        color. Raises on any other shape — parse constants once, at startup."""
        var bytes = text.as_bytes()
        var offset = 0
        if len(bytes) > 0 and bytes[0] == UInt8(ord("#")):
            offset = 1
        if len(bytes) - offset != 6:
            raise Error(
                "color.Color: from_hex expects '#rrggbb' or 'rrggbb', got '"
                + text
                + "'"
            )
        var red = _hex_pair(bytes, offset, text)
        var green = _hex_pair(bytes, offset + 2, text)
        var blue = _hex_pair(bytes, offset + 4, text)
        return Color.rgb(red=red, green=green, blue=blue)

    # --- Capability ----------------------------------------------------------

    def downgrade_to(self, level: ColorLevel) -> Color:
        """The nearest color renderable at `level`. Identity at or above this
        color's own tier; `NONE` is a rendering decision, not a color
        transform, so it also returns the color unchanged."""
        if level >= ColorLevel.TRUECOLOR or level == ColorLevel.NONE:
            return self
        if self._kind == _KIND_RGB:
            var index = rgb_to_ansi256(Int(self._a), Int(self._b), Int(self._c))
            if level == ColorLevel.ANSI256:
                return Color.ansi256(index)
            return Color._named(ansi256_to_named16(index))
        if self._kind == _KIND_ANSI256 and level == ColorLevel.ANSI16:
            return Color._named(ansi256_to_named16(self._a))
        return self

    # --- Package-private accessors (rendering internals) ---------------------

    @always_inline
    def _is_named(self) -> Bool:
        return self._kind == _KIND_NAMED

    @always_inline
    def _is_ansi256(self) -> Bool:
        return self._kind == _KIND_ANSI256

    @always_inline
    def _is_rgb(self) -> Bool:
        return self._kind == _KIND_RGB

    @always_inline
    def _payload(self) -> Tuple[UInt8, UInt8, UInt8]:
        return (self._a, self._b, self._c)

    # --- Comparable ----------------------------------------------------------

    @always_inline
    def _packed(self) -> UInt32:
        return (
            (UInt32(self._kind) << 24)
            | (UInt32(self._a) << 16)
            | (UInt32(self._b) << 8)
            | UInt32(self._c)
        )

    @always_inline
    def __eq__(self, other: Color) -> Bool:
        return self._packed() == other._packed()

    @always_inline
    def __ne__(self, other: Color) -> Bool:
        return self._packed() != other._packed()

    @always_inline
    def __lt__(self, other: Color) -> Bool:
        return self._packed() < other._packed()

    @always_inline
    def __le__(self, other: Color) -> Bool:
        return self._packed() <= other._packed()

    @always_inline
    def __gt__(self, other: Color) -> Bool:
        return self._packed() > other._packed()

    @always_inline
    def __ge__(self, other: Color) -> Bool:
        return self._packed() >= other._packed()

    # --- The sixteen named colors (palette indexes 0..15) --------------------

    comptime BLACK: Color = Color._named(UInt8(0))
    comptime RED: Color = Color._named(UInt8(1))
    comptime GREEN: Color = Color._named(UInt8(2))
    comptime YELLOW: Color = Color._named(UInt8(3))
    comptime BLUE: Color = Color._named(UInt8(4))
    comptime MAGENTA: Color = Color._named(UInt8(5))
    comptime CYAN: Color = Color._named(UInt8(6))
    comptime WHITE: Color = Color._named(UInt8(7))
    comptime BRIGHT_BLACK: Color = Color._named(UInt8(8))
    comptime BRIGHT_RED: Color = Color._named(UInt8(9))
    comptime BRIGHT_GREEN: Color = Color._named(UInt8(10))
    comptime BRIGHT_YELLOW: Color = Color._named(UInt8(11))
    comptime BRIGHT_BLUE: Color = Color._named(UInt8(12))
    comptime BRIGHT_MAGENTA: Color = Color._named(UInt8(13))
    comptime BRIGHT_CYAN: Color = Color._named(UInt8(14))
    comptime BRIGHT_WHITE: Color = Color._named(UInt8(15))


# --- Private helpers ----------------------------------------------------------


@always_inline
def _hex_pair(
    bytes: Span[UInt8, _], offset: Int, original: String
) raises -> UInt8:
    var high = _hex_nibble(bytes[offset], original)
    var low = _hex_nibble(bytes[offset + 1], original)
    return UInt8(high * 16 + low)


@always_inline
def _hex_nibble(byte: UInt8, original: String) raises -> Int:
    if byte >= UInt8(ord("0")) and byte <= UInt8(ord("9")):
        return Int(byte - UInt8(ord("0")))
    if byte >= UInt8(ord("a")) and byte <= UInt8(ord("f")):
        return Int(byte - UInt8(ord("a"))) + 10
    if byte >= UInt8(ord("A")) and byte <= UInt8(ord("F")):
        return Int(byte - UInt8(ord("A"))) + 10
    raise Error(
        "color.Color: from_hex found a non-hexadecimal digit in '"
        + original
        + "'"
    )
