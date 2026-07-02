# visible — the visible-text view of bytes that may contain escape
# sequences. `strip_escapes` returns the text a reader actually sees;
# `visible_width` counts its code points without materializing it. Both
# operate on foreign text and touch no other public type — integrators can
# strip and measure without the color machinery (ARCHITECTURE.md, System Map).
#
# Recognized sequence classes (ECMA-48 §5.3/§5.4/§5.6; real-world
# three-byte forms per RFC 1468): CSI (ESC [ .. final 0x40..0x7E); the
# command strings — OSC (ESC ] .. BEL or ST) and DCS/SOS/PM/APC
# (ESC P/X/^/_ .. ST, where BEL is payload, not a terminator); and plain
# escape sequences (ESC + intermediates 0x20..0x2F + final 0x30..0x7E).
# Note the final-byte range covers every ASCII letter: ESC followed by a
# letter is a real two-byte sequence a terminal would consume — exactly
# what a terminal shows is what survives here. The 8-bit C1 forms (0x9B
# CSI, 0x9C ST, ...) are deliberately not parsed: they collide with UTF-8
# continuation bytes (references/README.md, consequence #3). A dangling ESC
# — at the end of input, or before a byte that opens no sequence (controls,
# DEL, non-ASCII) — is preserved verbatim and counts as one column.
#
# Scanning for ESC bytewise is provably safe in UTF-8: ASCII values never
# occur inside multi-byte sequences (RFC 3629 §1). Width counts code points
# — bytes outside 0x80..0xBF (RFC 3629 §3); wide-glyph typography is a
# documented non-goal (UAX #11).

from std.memory import memcpy

from color._internal.sgr import (
    BACKSLASH,
    BELL,
    ESCAPE,
    LEFT_BRACKET,
    RIGHT_BRACKET,
    is_csi_final,
    is_csi_intermediate,
    is_csi_parameter,
    is_escape_final,
    is_string_introducer,
)


comptime _SIMD_WIDTH: Int = 16  # one SSE2 register; wider shows no gain here


comptime _MODE_COUNT_BYTES: Int = 0
comptime _MODE_COUNT_POINTS: Int = 1
comptime _MODE_WRITE: Int = 2


def strip_escapes(text: String) -> String:
    """Return `text` with every recognized escape sequence removed. Plain
    bytes pass through untouched; a dangling `ESC` is preserved. Exactly one
    allocation, sized by a counting pass over the same walk that writes."""
    var bytes = text.as_bytes()
    var scratch = String("")
    var visible_length = _walk[_MODE_COUNT_BYTES](bytes, scratch)
    if visible_length == len(bytes):
        return text.copy()

    var result = String(unsafe_uninit_length=visible_length)
    _ = _walk[_MODE_WRITE](bytes, result)
    return result^


def visible_width(text: String) -> Int:
    """Code points a reader sees: escape sequences are zero, every code
    point elsewhere is one (RFC 3629 byte classes). Cheaper than measuring
    `strip_escapes` output — nothing is allocated."""
    var bytes = text.as_bytes()
    var scratch = String("")
    return _walk[_MODE_COUNT_POINTS](bytes, scratch)


def _walk[mode: Int](bytes: Span[UInt8, _], mut destination: String) -> Int:
    """The single scan protocol behind sizing, measuring, and writing —
    one control flow, selected per use by a comptime mode, so the unsafe
    fill in `strip_escapes` can never disagree with the pass that sized it.
    Returns visible bytes, visible code points, or bytes written; the
    destination is touched only in write mode."""
    var length = len(bytes)
    var result = 0
    var index = 0
    while index < length:
        var escape_at = _find_escape_simd(bytes, index)
        comptime if mode == _MODE_COUNT_BYTES:
            result += escape_at - index
        comptime if mode == _MODE_COUNT_POINTS:
            result += _code_point_count(bytes, index, escape_at)
        comptime if mode == _MODE_WRITE:
            if escape_at > index:
                memcpy(
                    dest=destination.unsafe_ptr_mut() + result,
                    src=bytes.unsafe_ptr() + index,
                    count=escape_at - index,
                )
                result += escape_at - index
        if escape_at >= length:
            break
        var sequence_end = _skip_escape_sequence(bytes, escape_at)
        if sequence_end == escape_at:
            # Dangling ESC: stays visible — one byte, one column.
            comptime if mode == _MODE_WRITE:
                destination.unsafe_ptr_mut()[result] = ESCAPE
            result += 1
            index = escape_at + 1
        else:
            index = sequence_end
    return result


# --- Private helpers -----------------------------------------------------------


@always_inline
def _find_escape_simd(bytes: Span[UInt8, _], start: Int) -> Int:
    """Byte offset of the next `ESC` at or after `start`, or the length if
    none. One vector compare per 16-byte chunk on escape-free runs."""
    var length = len(bytes)
    var index = start
    var pointer = bytes.unsafe_ptr()
    while index + _SIMD_WIDTH <= length:
        var chunk = (pointer + index).load[width=_SIMD_WIDTH]()
        var hits = chunk.eq(SIMD[DType.uint8, _SIMD_WIDTH](ESCAPE))
        if hits.reduce_or():
            for offset in range(_SIMD_WIDTH):
                if (pointer + index + offset)[0] == ESCAPE:
                    return index + offset
        index += _SIMD_WIDTH
    while index < length:
        if (pointer + index)[0] == ESCAPE:
            return index
        index += 1
    return length


def _skip_escape_sequence(bytes: Span[UInt8, _], start: Int) -> Int:
    """Given `bytes[start] == ESC`, return the index just past the sequence.
    Returns `start` unchanged when the ESC opens no recognized sequence —
    the caller preserves it. An unterminated sequence consumes to the end."""
    var length = len(bytes)
    if start + 1 >= length:
        return start

    var introducer = bytes[start + 1]

    if introducer == LEFT_BRACKET:
        # CSI: parameters and intermediates, then one final byte.
        var index = start + 2
        while index < length and (
            is_csi_parameter(bytes[index]) or is_csi_intermediate(bytes[index])
        ):
            index += 1
        if index >= length:
            return length  # truncated at end of input — nothing follows
        if is_csi_final(bytes[index]):
            return index + 1
        # Aborted by a foreign byte (a new ESC, a C0 control, a UTF-8 byte):
        # the sequence ends here and that byte is processed normally — a
        # broken CSI never swallows the text after it (ECMA-48: ESC always
        # begins anew; controls execute).
        return index

    if introducer == RIGHT_BRACKET:
        # OSC: terminated by BEL (xterm practice) or by ST (ESC backslash).
        return _skip_command_string[bel_terminates=True](bytes, start)

    if is_string_introducer(introducer):
        # DCS, SOS, PM, APC (ECMA-48 §5.6): a command string terminated by
        # ST only — BEL is payload inside these, not a terminator.
        return _skip_command_string[bel_terminates=False](bytes, start)

    if is_csi_intermediate(introducer):
        # Plain escape sequence with intermediates: ESC 0x20..0x2F .. final.
        var index = start + 2
        while index < length and is_csi_intermediate(bytes[index]):
            index += 1
        if index >= length:
            return length  # truncated at end of input
        if is_escape_final(bytes[index]):
            return index + 1
        return index  # aborted — the foreign byte is processed normally

    if is_escape_final(introducer):
        # Two-byte escape sequence: ESC final.
        return start + 2

    return start


@always_inline
def _skip_command_string[
    bel_terminates: Bool
](bytes: Span[UInt8, _], start: Int) -> Int:
    """Index just past a command string opened at `bytes[start] == ESC`
    (OSC, DCS, SOS, PM, APC): the payload runs to ST (ESC backslash) — or
    to BEL when `bel_terminates`, the xterm OSC convention. A bare ESC ends
    the string so the next sequence is processed normally; an unterminated
    string consumes to the end of input. The terminator set is a comptime
    parameter so each caller compiles to a branch-free-per-byte loop."""
    var length = len(bytes)
    var index = start + 2
    while index < length:
        comptime if bel_terminates:
            if bytes[index] == BELL:
                return index + 1
        if bytes[index] == ESCAPE:
            if index + 1 < length and bytes[index + 1] == BACKSLASH:
                return index + 2
            return index  # a new sequence begins; stop consuming here
        index += 1
    return length


@always_inline
def _code_point_count(bytes: Span[UInt8, _], start: Int, end: Int) -> Int:
    """Code points in `bytes[start..end)`: bytes outside the UTF-8
    continuation range 0x80..0xBF (RFC 3629 §3)."""
    var count = 0
    for index in range(start, end):
        if (bytes[index] & UInt8(0xC0)) != UInt8(0x80):
            count += 1
    return count
