# Probe: differential sweep of _internal/quantize against the Python
# reference — every RGB grid point at step 15 (18^3 = 5832 combinations).
# Run: pixi run mojo run -I . .probe/probe_quantize_sweep.mojo | python3 .probe/quantize_sweep_check.py
# The checker exits non-zero on any divergence.

from color._internal.quantize import ansi256_to_named16, rgb_to_ansi256


def main():
    for red in range(0, 256, 15):
        for green in range(0, 256, 15):
            for blue in range(0, 256, 15):
                var index = rgb_to_ansi256(red, green, blue)
                var named = ansi256_to_named16(index)
                print(red, green, blue, Int(index), Int(named))
