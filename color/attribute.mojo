"""Defines composable ANSI SGR text attributes."""

# Attribute — the SGR text-attribute set as a single-byte bitmask. Combine
# with `|` (`Attribute.BOLD | Attribute.UNDERLINE`); test membership with
# `contains`. Bit positions are a rendering contract: bit i emits the SGR
# code at _internal/sgr.ATTRIBUTE_CODES[i].


struct Attribute(Comparable, Copyable, Movable, TrivialRegisterPassable):
    """Set of SGR text attributes — eight independent flags in one byte.
    Bitwise `|` and `&` produce new sets; nothing mutates."""

    var _bits: UInt8

    @doc_hidden
    @always_inline
    def __init__(out self, *, bits: UInt8):
        self._bits = bits

    @always_inline
    def bits(self) -> UInt8:
        """Gets the raw bitmask consumed by rendering internals.

        Returns:
            The attribute bitmask.
        """
        return self._bits

    @always_inline
    def __or__(self, other: Attribute) -> Attribute:
        """Combines two attribute sets.

        Args:
            other: The attributes to add.

        Returns:
            The union of both attribute sets.
        """
        return Attribute(bits=self._bits | other._bits)

    @always_inline
    def __and__(self, other: Attribute) -> Attribute:
        """Intersects two attribute sets.

        Args:
            other: The attributes to intersect.

        Returns:
            The attributes present in both sets.
        """
        return Attribute(bits=self._bits & other._bits)

    @always_inline
    def contains(self, other: Attribute) -> Bool:
        """Checks whether every requested attribute is present.

        Args:
            other: The attributes to test.

        Returns:
            True if every attribute in `other` is present.
        """
        return (self._bits & other._bits) == other._bits

    @always_inline
    def is_empty(self) -> Bool:
        """Checks whether the set contains no attributes.

        Returns:
            True if no attribute bits are set.
        """
        return self._bits == UInt8(0)

    @always_inline
    def __eq__(self, other: Attribute) -> Bool:
        """Checks two attribute sets for equality.

        Args:
            other: The attribute set to compare.

        Returns:
            True if both sets have identical bits.
        """
        return self._bits == other._bits

    @always_inline
    def __ne__(self, other: Attribute) -> Bool:
        """Checks two attribute sets for inequality.

        Args:
            other: The attribute set to compare.

        Returns:
            True if the sets have different bits.
        """
        return self._bits != other._bits

    @always_inline
    def __lt__(self, other: Attribute) -> Bool:
        """Orders attribute sets by their raw bitmasks.

        Args:
            other: The attribute set to compare.

        Returns:
            True if this bitmask is smaller.
        """
        return self._bits < other._bits

    @always_inline
    def __le__(self, other: Attribute) -> Bool:
        """Orders attribute sets by their raw bitmasks.

        Args:
            other: The attribute set to compare.

        Returns:
            True if this bitmask is no greater.
        """
        return self._bits <= other._bits

    @always_inline
    def __gt__(self, other: Attribute) -> Bool:
        """Orders attribute sets by their raw bitmasks.

        Args:
            other: The attribute set to compare.

        Returns:
            True if this bitmask is greater.
        """
        return self._bits > other._bits

    @always_inline
    def __ge__(self, other: Attribute) -> Bool:
        """Orders attribute sets by their raw bitmasks.

        Args:
            other: The attribute set to compare.

        Returns:
            True if this bitmask is no smaller.
        """
        return self._bits >= other._bits

    # Bit i renders as _internal/sgr.ATTRIBUTE_CODES[i] — order is load-bearing.
    comptime NONE: Attribute = Attribute(bits=UInt8(0))
    """No text attributes."""
    comptime BOLD: Attribute = Attribute(bits=UInt8(1) << 0)
    """Bold or increased-intensity text."""
    comptime DIM: Attribute = Attribute(bits=UInt8(1) << 1)
    """Dim or decreased-intensity text."""
    comptime ITALIC: Attribute = Attribute(bits=UInt8(1) << 2)
    """Italicized text."""
    comptime UNDERLINE: Attribute = Attribute(bits=UInt8(1) << 3)
    """Underlined text."""
    comptime BLINK: Attribute = Attribute(bits=UInt8(1) << 4)
    """Blinking text where supported."""
    comptime REVERSE: Attribute = Attribute(bits=UInt8(1) << 5)
    """Text with foreground and background reversed."""
    comptime HIDDEN: Attribute = Attribute(bits=UInt8(1) << 6)
    """Hidden or concealed text."""
    comptime STRIKETHROUGH: Attribute = Attribute(bits=UInt8(1) << 7)
    """Struck-through text."""
