# Attribute — the SGR text-attribute set as a single-byte bitmask. Combine
# with `|` (`Attribute.BOLD | Attribute.UNDERLINE`); test membership with
# `contains`. Bit positions are a rendering contract: bit i emits the SGR
# code at _internal/sgr.ATTRIBUTE_CODES[i].


struct Attribute(Comparable, Copyable, Movable, TrivialRegisterPassable):
    """Set of SGR text attributes — eight independent flags in one byte.
    Bitwise `|` and `&` produce new sets; nothing mutates."""

    var _bits: UInt8

    @always_inline
    def __init__(out self, *, bits: UInt8):
        self._bits = bits

    @always_inline
    def bits(self) -> UInt8:
        """The raw bitmask — consumed by the rendering internals."""
        return self._bits

    @always_inline
    def __or__(self, other: Attribute) -> Attribute:
        return Attribute(bits=self._bits | other._bits)

    @always_inline
    def __and__(self, other: Attribute) -> Attribute:
        return Attribute(bits=self._bits & other._bits)

    @always_inline
    def contains(self, other: Attribute) -> Bool:
        """True iff every attribute set in `other` is also set in `self`."""
        return (self._bits & other._bits) == other._bits

    @always_inline
    def is_empty(self) -> Bool:
        return self._bits == UInt8(0)

    @always_inline
    def __eq__(self, other: Attribute) -> Bool:
        return self._bits == other._bits

    @always_inline
    def __ne__(self, other: Attribute) -> Bool:
        return self._bits != other._bits

    @always_inline
    def __lt__(self, other: Attribute) -> Bool:
        return self._bits < other._bits

    @always_inline
    def __le__(self, other: Attribute) -> Bool:
        return self._bits <= other._bits

    @always_inline
    def __gt__(self, other: Attribute) -> Bool:
        return self._bits > other._bits

    @always_inline
    def __ge__(self, other: Attribute) -> Bool:
        return self._bits >= other._bits

    # Bit i renders as _internal/sgr.ATTRIBUTE_CODES[i] — order is load-bearing.
    comptime NONE: Attribute = Attribute(bits=UInt8(0))
    comptime BOLD: Attribute = Attribute(bits=UInt8(1) << 0)
    comptime DIM: Attribute = Attribute(bits=UInt8(1) << 1)
    comptime ITALIC: Attribute = Attribute(bits=UInt8(1) << 2)
    comptime UNDERLINE: Attribute = Attribute(bits=UInt8(1) << 3)
    comptime BLINK: Attribute = Attribute(bits=UInt8(1) << 4)
    comptime REVERSE: Attribute = Attribute(bits=UInt8(1) << 5)
    comptime HIDDEN: Attribute = Attribute(bits=UInt8(1) << 6)
    comptime STRIKETHROUGH: Attribute = Attribute(bits=UInt8(1) << 7)
