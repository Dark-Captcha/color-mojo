# Style — composable styling intent: optional foreground, optional
# background, attribute set. Build fluently (`Style().foreground(Color.RED)
# .bold()`); render verbatim with `paint` / `paint_into`. Style knows WHAT —
# it renders exactly as declared. Capability belongs to Painter, which knows
# WHERE (ARCHITECTURE.md, Conventions).
#
# Rendering assembles the SGR open sequence exactly once, into a
# comptime-bounded stack buffer (`_OPEN_CAPACITY`): the same pass sizes and
# renders, so the length that reaches the allocator cannot disagree with the
# bytes. `paint` then makes its single exact-length allocation and
# bulk-copies open + text + reset; `paint_into` wraps the stack bytes in a
# StringSlice view and streams — no allocation at all (.probe/SYNTAX.md,
# findings 4, 12, 13). The assembled bytes are ASCII escape parameters plus
# the caller's already-valid UTF-8, so the non-validating constructor is
# sound. Every paint is self-closing: open, text, reset — always.
#
# The render chain is `@always_inline` end to end: a call site whose Style
# is a compile-time constant — every Painter sugar method — constant-folds
# the emission down to a handful of byte stores.

from std.memory import memcpy

from color._internal.decimal import write_decimal
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


# Worst-case open sequence: ESC [ (2 bytes) + eight attributes as "N;" (16)
# + an RGB foreground "38;2;255;255;255;" (17) + an RGB background
# "48;2;255;255;255;" (17) = 52 bytes — the trailing separator slot becomes
# the final `m`. Rounded up to the next power of two for the stack buffer.
comptime _OPEN_CAPACITY: Int = 64


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

    @always_inline
    def paint(self, text: String) -> String:
        """Wrap `text` in this style's SGR open sequence and the reset close.
        One exact-length allocation; the empty style returns `text` unchanged."""
        if self.is_empty():
            return text.copy()

        var buffer = InlineArray[UInt8, _OPEN_CAPACITY](uninitialized=True)
        var open_length = self._write_open_sequence(buffer)
        var reset = RESET_SEQUENCE.as_bytes()
        var total = open_length + text.byte_length() + len(reset)

        var result = String(unsafe_uninit_length=total)
        var offset = _write_bytes(result, 0, Span(buffer)[0:open_length])
        offset = _write_bytes(result, offset, text.as_bytes())
        _ = _write_bytes(result, offset, reset)
        return result^

    @always_inline
    def paint_into[W: Writer](self, mut writer: W, text: String):
        """Write the styled text into `writer` without allocating: the open
        sequence is assembled on the stack and viewed in place; the text
        body streams through unbuffered."""
        if self.is_empty():
            writer.write(text)
            return
        var buffer = InlineArray[UInt8, _OPEN_CAPACITY](uninitialized=True)
        var open_length = self._write_open_sequence(buffer)
        var open_sequence = StringSlice(
            unsafe_from_utf8=Span(buffer)[0:open_length]
        )
        writer.write(open_sequence, text, RESET_SEQUENCE)

    # --- Private rendering core ------------------------------------------------

    @always_inline
    def _write_open_sequence(
        self, mut buffer: InlineArray[UInt8, _OPEN_CAPACITY]
    ) -> Int:
        """Write `ESC [ params m` into the stack buffer; return the byte
        length written. The buffer never moves, so one pointer serves the
        whole pass. The caller guarantees the style is non-empty — at least
        one parameter is written, so the trailing separator slot exists."""
        var pointer = buffer.unsafe_ptr()
        pointer[0] = ESCAPE
        pointer[1] = LEFT_BRACKET
        var offset = 2

        var bits = self._attributes.bits()
        if bits != UInt8(0):
            var codes = ATTRIBUTE_CODES.as_bytes()
            for position in range(8):
                if (bits & (UInt8(1) << UInt8(position))) != UInt8(0):
                    pointer[offset] = codes[position]
                    pointer[offset + 1] = SEMICOLON
                    offset += 2

        if self._foreground:
            offset = _write_color_parameter(
                buffer, offset, self._foreground.value(), base=30
            )
        if self._background:
            offset = _write_color_parameter(
                buffer, offset, self._background.value(), base=40
            )

        # The trailing separator slot becomes the SGR final byte.
        buffer.unsafe_ptr()[offset - 1] = SGR_FINAL
        return offset


# --- Private helpers -----------------------------------------------------------


@always_inline
def _named_code(index: UInt8, *, base: Int) -> Int:
    """SGR code for named palette index 0..15: 30..37 / 90..97 for the
    foreground base 30, 40..47 / 100..107 for the background base 40. The
    bright halves are the aixterm extension, not ECMA-48 — universally
    rendered (references/README.md, External Specifications)."""
    if index < UInt8(8):
        return base + Int(index)
    return base + 60 + Int(index) - 8


@always_inline
def _write_color_parameter(
    mut buffer: InlineArray[UInt8, _OPEN_CAPACITY],
    offset: Int,
    color: Color,
    *,
    base: Int,
) -> Int:
    """Write one color's SGR parameter followed by a separator; return the
    offset after the separator. `base` is 30 for foreground, 40 for
    background — extended forms use `base + 8` (38/48, ITU-T T.416)."""
    var payload = color._payload()
    var next = offset

    if color._is_named():
        next = write_decimal(buffer, next, _named_code(payload[0], base=base))
        buffer.unsafe_ptr()[next] = SEMICOLON
        return next + 1

    next = write_decimal(buffer, next, base + 8)
    var pointer = buffer.unsafe_ptr()
    pointer[next] = SEMICOLON
    if color._is_ansi256():
        pointer[next + 1] = UInt8(ord("5"))
        pointer[next + 2] = SEMICOLON
        next = write_decimal(buffer, next + 3, Int(payload[0]))
    else:
        pointer[next + 1] = UInt8(ord("2"))
        pointer[next + 2] = SEMICOLON
        next = write_decimal(buffer, next + 3, Int(payload[0]))
        pointer[next] = SEMICOLON
        next = write_decimal(buffer, next + 1, Int(payload[1]))
        pointer[next] = SEMICOLON
        next = write_decimal(buffer, next + 1, Int(payload[2]))
    pointer[next] = SEMICOLON
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
