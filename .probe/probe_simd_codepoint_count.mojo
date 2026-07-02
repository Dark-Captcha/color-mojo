# Probe: SIMD code-point counting — count bytes outside the UTF-8
# continuation range 0x80..0xBF in a 16-byte chunk with one mask and one
# horizontal add (RFC 3629 §3: non-continuation bytes start code points).
# Run: pixi run mojo run .probe/probe_simd_codepoint_count.mojo


def main():
    # "café ALERT" prefix padded: 'c','a','f',0xC3,0xA9,' ','A'... — the
    # two-byte é contributes one non-continuation byte.
    var chunk = SIMD[DType.uint8, 16](0x41)  # 'A' filler
    chunk[3] = 0xC3  # é lead byte — counts
    chunk[4] = 0xA9  # é continuation — must not count

    var masked = chunk & SIMD[DType.uint8, 16](0xC0)
    var starts = masked.ne(SIMD[DType.uint8, 16](0x80))
    var ones = starts.select(
        SIMD[DType.uint8, 16](1), SIMD[DType.uint8, 16](0)
    )
    print(Int(ones.reduce_add()))  # expected: 15 (16 bytes, one continuation)
