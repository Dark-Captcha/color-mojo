# SGR wire-format constants and byte-class predicates — the single source for
# every byte this library emits or recognizes. Emission uses 7-bit forms
# exclusively; the 8-bit C1 CSI (0x9B) is deliberately absent because it is
# banned in network text and collides with UTF-8 continuation bytes
# (references/README.md, consequences #3 and #4).
#
# Authorities: ECMA-48 5th ed. §5.4 (sequence grammar), RFC 20 (byte values),
# ITU-T T.416 (extended color). See references/README.md.


comptime ESCAPE: UInt8 = UInt8(0x1B)
comptime LEFT_BRACKET: UInt8 = UInt8(ord("["))
comptime RIGHT_BRACKET: UInt8 = UInt8(ord("]"))
comptime SEMICOLON: UInt8 = UInt8(ord(";"))
comptime SGR_FINAL: UInt8 = UInt8(ord("m"))
comptime BELL: UInt8 = UInt8(0x07)
comptime BACKSLASH: UInt8 = UInt8(ord("\\"))

comptime RESET_SEQUENCE: StaticString = "\x1b[0m"

# One ASCII digit per attribute bit position: bit i renders as SGR code
# ATTRIBUTE_CODES[i]. Order is a contract with attribute.mojo — bold, dim,
# italic, underline, blink, reverse, hidden, strikethrough. SGR 6 is unused.
comptime ATTRIBUTE_CODES: StaticString = "12345789"


@always_inline
def is_csi_parameter(byte: UInt8) -> Bool:
    """CSI parameter byte, ECMA-48 §5.4: 0x30..0x3F."""
    return byte >= UInt8(0x30) and byte <= UInt8(0x3F)


@always_inline
def is_csi_intermediate(byte: UInt8) -> Bool:
    """CSI or escape intermediate byte, ECMA-48 §5.4: 0x20..0x2F."""
    return byte >= UInt8(0x20) and byte <= UInt8(0x2F)


@always_inline
def is_csi_final(byte: UInt8) -> Bool:
    """CSI final byte, ECMA-48 §5.4: 0x40..0x7E."""
    return byte >= UInt8(0x40) and byte <= UInt8(0x7E)


@always_inline
def is_escape_final(byte: UInt8) -> Bool:
    """Final byte of a non-CSI escape sequence, ECMA-48 §5.3: 0x30..0x7E."""
    return byte >= UInt8(0x30) and byte <= UInt8(0x7E)
