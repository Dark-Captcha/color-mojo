# Style — composable styling intent: optional foreground, optional
# background, attribute set. Build fluently (`Style().foreground(Color.RED)
# .bold()`); render verbatim with `paint` / `paint_into`. Style knows WHAT —
# it renders exactly as declared. Capability belongs to Painter, which knows
# WHERE (ARCHITECTURE.md, Conventions).
#
# Rendering allocates once: the exact output length is computed up front,
# a String of that length is created uninitialized, and every byte is written
# in place (.probe/SYNTAX.md, findings 3 and 4). The assembled bytes are
# ASCII escape parameters plus the caller's already-valid UTF-8, so the
# non-validating constructor is sound. Every paint is self-closing:
# open, text, reset — always.

from std.bit import pop_count
from std.memory import memcpy

from color._internal.decimal import decimal_length, write_decimal
from color._internal.sgr import (
    ATTRIBUTE_CODES,
    ESCAPE,
    LEFT_BRACKET,
    RESET_SEQUENCE,
    SEMICOLON,
    SGR_FINAL,
)
from color.attribute import Attribute
from color.color import Color


struct Style(Copyable, Movable):
    """Styling intent as a value: foreground, background, attributes. Each
    builder method returns a new `Style`; nothing mutates. `paint` renders
    the declaration verbatim — route through a `Painter` for output that
    honors the destination's capability."""

    var _foreground: Optional[Color]
    var _background: Optional[Color]
    var _attributes: Attribute

    @always_inline
    def __init__(out self):
        """The empty style — `paint(text)` returns `text` unchanged."""
        self._foreground = None
        self._background = None
        self._attributes = Attribute.NONE

    @always_inline
    def __init__(
        out self,
        *,
        foreground: Optional[Color],
        background: Optional[Color],
        attributes: Attribute,
    ):
        self._foreground = foreground
        self._background = background
        self._attributes = attributes

    # --- Builder --------------------------------------------------------------

    @always_inline
    def foreground(self, color: Color) -> Style:
        """A new style with the foreground set to `color`."""
        var next = Style(
            foreground=Optional[Color](color),
            background=self._background,
            attributes=self._attributes,
        )
        return next^

    @always_inline
    def background(self, color: Color) -> Style:
        """A new style with the background set to `color`."""
        var next = Style(
            foreground=self._foreground,
            background=Optional[Color](color),
            attributes=self._attributes,
        )
        return next^

    @always_inline
    def attribute(self, attribute: Attribute) -> Style:
        """A new style with `attribute` merged in — accepts combined sets."""
        var next = Style(
            foreground=self._foreground,
            background=self._background,
            attributes=self._attributes | attribute,
        )
        return next^

    @always_inline
    def bold(self) -> Style:
        return self.attribute(Attribute.BOLD)

    @always_inline
    def dim(self) -> Style:
        return self.attribute(Attribute.DIM)

    @always_inline
    def italic(self) -> Style:
        return self.attribute(Attribute.ITALIC)

    @always_inline
    def underline(self) -> Style:
        return self.attribute(Attribute.UNDERLINE)

    @always_inline
    def blink(self) -> Style:
        return self.attribute(Attribute.BLINK)

    @always_inline
    def reverse(self) -> Style:
        return self.attribute(Attribute.REVERSE)

    @always_inline
    def hidden(self) -> Style:
        return self.attribute(Attribute.HIDDEN)

    @always_inline
    def strikethrough(self) -> Style:
        return self.attribute(Attribute.STRIKETHROUGH)

    # --- Inspection -----------------------------------------------------------

    @always_inline
    def is_empty(self) -> Bool:
        """True when painting would not change the text at all."""
        return (
            not self._foreground
            and not self._background
            and self._attributes.is_empty()
        )

    # --- Rendering ------------------------------------------------------------

    def paint(self, text: String) -> String:
        """Wrap `text` in this style's SGR open sequence and the reset close.
        One exact-length allocation; the empty style returns `text` unchanged."""
        if self.is_empty():
            return text.copy()

        # ESC [ plus parameters; the last separator's slot becomes the final
        # byte `m`, so the parameter length already covers it.
        var open_length = 2 + self._parameters_length()
        var reset = RESET_SEQUENCE.as_bytes()
        var total = open_length + text.byte_length() + len(reset)

        var result = String(unsafe_uninit_length=total)
        var offset = self._write_open_sequence(result)
        offset = _write_bytes(result, offset, text.as_bytes())
        _ = _write_bytes(result, offset, reset)
        return result^

    def paint_into[W: Writer](self, mut writer: W, text: String):
        """Write the styled text into `writer` without building the full
        line: only the open sequence (at most a few dozen bytes) is
        materialized; the text body streams through unbuffered."""
        if self.is_empty():
            writer.write(text)
            return
        var open_length = 2 + self._parameters_length()
        var open_sequence = String(unsafe_uninit_length=open_length)
        _ = self._write_open_sequence(open_sequence)
        writer.write(open_sequence, text, RESET_SEQUENCE)

    # --- Private rendering core ------------------------------------------------

    def _parameters_length(self) -> Int:
        """Byte length of the SGR parameter list including one trailing
        separator per parameter (the last separator's slot becomes `m`)."""
        # Each set attribute contributes one digit plus one separator.
        var length = 2 * Int(pop_count(self._attributes.bits()))
        if self._foreground:
            length += _color_parameter_length(self._foreground.value(), base=30)
        if self._background:
            length += _color_parameter_length(self._background.value(), base=40)
        return length

    def _write_open_sequence(self, mut destination: String) -> Int:
        """Write `ESC [ params m` at the start of `destination`; return the
        offset just past `m`. The caller sized the buffer via
        `_parameters_length`."""
        var pointer = destination.unsafe_ptr_mut()
        pointer[0] = ESCAPE
        pointer[1] = LEFT_BRACKET
        var offset = 2

        var codes = ATTRIBUTE_CODES.as_bytes()
        var bits = self._attributes.bits()
        for position in range(8):
            if (bits & (UInt8(1) << UInt8(position))) != UInt8(0):
                pointer[offset] = codes[position]
                pointer[offset + 1] = SEMICOLON
                offset += 2

        if self._foreground:
            offset = _write_color_parameter(
                destination, offset, self._foreground.value(), base=30
            )
        if self._background:
            offset = _write_color_parameter(
                destination, offset, self._background.value(), base=40
            )

        # The trailing separator slot becomes the SGR final byte. is_empty()
        # guarantees at least one parameter was written.
        destination.unsafe_ptr_mut()[offset - 1] = SGR_FINAL
        return offset


# --- Private helpers -----------------------------------------------------------


@always_inline
def _color_parameter_length(color: Color, *, base: Int) -> Int:
    """Length of one color's parameter text plus its trailing separator.
    `base` matters: bright background codes (100..107) are three digits
    where their foreground twins (90..97) are two."""
    var payload = color._payload()
    if color._is_named():
        return decimal_length(_named_code(payload[0], base=base)) + 1
    if color._is_ansi256():
        # "38;5;" + index + separator
        return 5 + decimal_length(Int(payload[0])) + 1
    # "38;2;" + red;green;blue + separator
    return (
        5
        + decimal_length(Int(payload[0]))
        + 1
        + decimal_length(Int(payload[1]))
        + 1
        + decimal_length(Int(payload[2]))
        + 1
    )


@always_inline
def _named_code(index: UInt8, *, base: Int) -> Int:
    """SGR code for named palette index 0..15: 30..37 / 90..97 for the
    foreground base 30, 40..47 / 100..107 for the background base 40."""
    if index < UInt8(8):
        return base + Int(index)
    return base + 60 + Int(index) - 8


def _write_color_parameter(
    mut destination: String, offset: Int, color: Color, *, base: Int
) -> Int:
    """Write one color's SGR parameter followed by a separator; return the
    offset after the separator. `base` is 30 for foreground, 40 for
    background — extended forms use `base + 8` (38/48, ITU-T T.416)."""
    var payload = color._payload()
    var next = offset

    if color._is_named():
        next = write_decimal(
            destination, next, _named_code(payload[0], base=base)
        )
        destination.unsafe_ptr_mut()[next] = SEMICOLON
        return next + 1

    next = write_decimal(destination, next, base + 8)
    var pointer = destination.unsafe_ptr_mut()
    pointer[next] = SEMICOLON
    if color._is_ansi256():
        pointer[next + 1] = UInt8(ord("5"))
        pointer[next + 2] = SEMICOLON
        next = write_decimal(destination, next + 3, Int(payload[0]))
    else:
        pointer[next + 1] = UInt8(ord("2"))
        pointer[next + 2] = SEMICOLON
        next = write_decimal(destination, next + 3, Int(payload[0]))
        var again = destination.unsafe_ptr_mut()
        again[next] = SEMICOLON
        next = write_decimal(destination, next + 1, Int(payload[1]))
        again = destination.unsafe_ptr_mut()
        again[next] = SEMICOLON
        next = write_decimal(destination, next + 1, Int(payload[2]))
    destination.unsafe_ptr_mut()[next] = SEMICOLON
    return next + 1


@always_inline
def _write_bytes(
    mut destination: String, offset: Int, source: Span[UInt8, _]
) -> Int:
    """Bulk-copy `source` into `destination` at `offset`; return the offset
    just past the copied bytes."""
    memcpy(
        dest=destination.unsafe_ptr_mut() + offset,
        src=source.unsafe_ptr(),
        count=len(source),
    )
    return offset + len(source)
