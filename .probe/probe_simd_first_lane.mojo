# Probe: first-set-lane extraction from a SIMD comparison mask — replaces
# the scalar re-scan after a vector hit in _find_escape_simd. Technique:
# select(iota, 255) then reduce_min; the sentinel loses to any real index.
# Run: pixi run mojo run .probe/probe_simd_first_lane.mojo

from std.math import iota


def main():
    var chunk = SIMD[DType.uint8, 16](0x20)
    chunk[5] = 0x1B
    chunk[9] = 0x1B

    var hits = chunk.eq(SIMD[DType.uint8, 16](0x1B))
    var indexes = iota[DType.uint8, 16]()
    var first = hits.select(indexes, SIMD[DType.uint8, 16](255)).reduce_min()
    print(Int(first))  # expected: 5

    var clean = SIMD[DType.uint8, 16](0x20)
    var misses = clean.eq(SIMD[DType.uint8, 16](0x1B))
    var none = misses.select(indexes, SIMD[DType.uint8, 16](255)).reduce_min()
    print(Int(none))  # expected: 255
