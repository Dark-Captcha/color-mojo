# quantize — nearest-match color reduction: 24-bit RGB to the xterm-256
# palette, and xterm-256 to the named 16. Distance is squared-integer in
# nominal sRGB space — a deliberate heuristic, not colorimetry
# (references/README.md, consequence #8).
#
# xterm-256 layout (XTerm ctlseqs): indexes 0..15 are the theme-dependent
# system colors (never produced as quantization targets); 16..231 form a
# 6x6x6 cube with per-channel levels 0,95,135,175,215,255 (level i is
# 55 + 40*i for i >= 1); 232..255 form a 24-step gray ramp at 8 + 10*k.
# Named-16 targets use xterm's default palette values.
#
# Differential-tested against .probe/quantize_reference.py.


@always_inline
def _cube_component_index(channel: Int) -> Int:
    if channel < 48:
        return 0
    if channel < 115:
        return 1
    return (channel - 35) // 40


@always_inline
def _cube_component_level(index: Int) -> Int:
    if index == 0:
        return 0
    return 55 + 40 * index


@always_inline
def _squared_distance(
    red: Int, green: Int, blue: Int, to_red: Int, to_green: Int, to_blue: Int
) -> Int:
    var dr = red - to_red
    var dg = green - to_green
    var db = blue - to_blue
    return dr * dr + dg * dg + db * db


def rgb_to_ansi256(red: Int, green: Int, blue: Int) -> UInt8:
    """Nearest xterm-256 index for an RGB triple — the better of the closest
    cube entry and the closest gray-ramp entry."""
    var red_index = _cube_component_index(red)
    var green_index = _cube_component_index(green)
    var blue_index = _cube_component_index(blue)
    var cube_index = 16 + 36 * red_index + 6 * green_index + blue_index
    var cube_distance = _squared_distance(
        red,
        green,
        blue,
        _cube_component_level(red_index),
        _cube_component_level(green_index),
        _cube_component_level(blue_index),
    )

    var average = (red + green + blue) // 3
    var gray_step = 0
    if average > 238:
        gray_step = 23
    elif average >= 8:
        gray_step = (average - 3) // 10
    var gray_level = 8 + 10 * gray_step
    var gray_distance = _squared_distance(
        red, green, blue, gray_level, gray_level, gray_level
    )

    if gray_distance < cube_distance:
        return UInt8(232 + gray_step)
    return UInt8(cube_index)


def ansi256_to_named16(index: UInt8) -> UInt8:
    """Nearest named-16 index (0..15) for an xterm-256 index. Indexes below
    16 map to themselves."""
    if index < UInt8(16):
        return index

    var red: Int
    var green: Int
    var blue: Int
    if index < UInt8(232):
        var cube = Int(index) - 16
        red = _cube_component_level(cube // 36)
        green = _cube_component_level((cube % 36) // 6)
        blue = _cube_component_level(cube % 6)
    else:
        var gray = (Int(index) - 232) * 10 + 8
        red = gray
        green = gray
        blue = gray

    var best = 0
    var best_distance = _distance_to_named16(red, green, blue, 0)
    for candidate in range(1, 16):
        var distance = _distance_to_named16(red, green, blue, candidate)
        if distance < best_distance:
            best = candidate
            best_distance = distance
    return UInt8(best)


@always_inline
def _distance_to_named16(red: Int, green: Int, blue: Int, index: Int) -> Int:
    """Squared distance from an RGB triple to named color `index` in xterm's
    default palette. A branch per color — InlineArray has no variadic-values
    constructor in this toolchain (.probe/SYNTAX.md)."""
    if index == 0:
        return _squared_distance(red, green, blue, 0, 0, 0)
    if index == 1:
        return _squared_distance(red, green, blue, 205, 0, 0)
    if index == 2:
        return _squared_distance(red, green, blue, 0, 205, 0)
    if index == 3:
        return _squared_distance(red, green, blue, 205, 205, 0)
    if index == 4:
        return _squared_distance(red, green, blue, 0, 0, 238)
    if index == 5:
        return _squared_distance(red, green, blue, 205, 0, 205)
    if index == 6:
        return _squared_distance(red, green, blue, 0, 205, 205)
    if index == 7:
        return _squared_distance(red, green, blue, 229, 229, 229)
    if index == 8:
        return _squared_distance(red, green, blue, 127, 127, 127)
    if index == 9:
        return _squared_distance(red, green, blue, 255, 0, 0)
    if index == 10:
        return _squared_distance(red, green, blue, 0, 255, 0)
    if index == 11:
        return _squared_distance(red, green, blue, 255, 255, 0)
    if index == 12:
        return _squared_distance(red, green, blue, 92, 92, 255)
    if index == 13:
        return _squared_distance(red, green, blue, 255, 0, 255)
    if index == 14:
        return _squared_distance(red, green, blue, 0, 255, 255)
    return _squared_distance(red, green, blue, 255, 255, 255)
