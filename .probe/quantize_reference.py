#!/usr/bin/env python3
# Reference implementation for color/_internal/quantize.mojo — generates the
# differential test vectors embedded in tests/run_tests.mojo. Formulas follow
# the xterm 256-color layout (references/README.md): color cube at indexes
# 16..231 with per-channel levels 0,95,135,175,215,255; gray ramp 8+10k at
# 232..255. Named-16 targets are xterm's default palette values.
# Run: python3 .probe/quantize_reference.py

XTERM_16 = [
    (0, 0, 0),
    (205, 0, 0),
    (0, 205, 0),
    (205, 205, 0),
    (0, 0, 238),
    (205, 0, 205),
    (0, 205, 205),
    (229, 229, 229),
    (127, 127, 127),
    (255, 0, 0),
    (0, 255, 0),
    (255, 255, 0),
    (92, 92, 255),
    (255, 0, 255),
    (0, 255, 255),
    (255, 255, 255),
]


def cube_level(index):
    return 0 if index == 0 else 55 + 40 * index


def cube_index(channel):
    if channel < 48:
        return 0
    if channel < 115:
        return 1
    return (channel - 35) // 40


def rgb_to_ansi256(red, green, blue):
    ir, ig, ib = cube_index(red), cube_index(green), cube_index(blue)
    cube = 16 + 36 * ir + 6 * ig + ib
    cr, cg, cb = cube_level(ir), cube_level(ig), cube_level(ib)
    cube_distance = (red - cr) ** 2 + (green - cg) ** 2 + (blue - cb) ** 2

    average = (red + green + blue) // 3
    k = 0 if average < 8 else (23 if average > 238 else (average - 3) // 10)
    gray = 8 + 10 * k
    gray_distance = (red - gray) ** 2 + (green - gray) ** 2 + (blue - gray) ** 2

    return 232 + k if gray_distance < cube_distance else cube


def ansi256_to_rgb(index):
    if index < 16:
        return XTERM_16[index]
    if index < 232:
        index -= 16
        return (
            cube_level(index // 36),
            cube_level((index % 36) // 6),
            cube_level(index % 6),
        )
    gray = (index - 232) * 10 + 8
    return (gray, gray, gray)


def ansi256_to_named16(index):
    if index < 16:
        return index
    red, green, blue = ansi256_to_rgb(index)
    best, best_distance = 0, 1 << 30
    for n, (nr, ng, nb) in enumerate(XTERM_16):
        d = (red - nr) ** 2 + (green - ng) ** 2 + (blue - nb) ** 2
        if d < best_distance:
            best, best_distance = n, d
    return best


VECTORS = [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 255),
    (0, 0, 0),
    (255, 100, 0),
    (0, 128, 128),
    (128, 128, 128),
    (250, 250, 250),
    (8, 8, 8),
    (1, 1, 1),
    (95, 135, 175),
    (255, 215, 0),
    (46, 52, 64),
]

if __name__ == "__main__":
    for red, green, blue in VECTORS:
        x = rgb_to_ansi256(red, green, blue)
        print(
            f"rgb({red:3},{green:3},{blue:3}) -> "
            f"256:{x:3} -> 16:{ansi256_to_named16(x):2}"
        )
