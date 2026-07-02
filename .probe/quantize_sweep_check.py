#!/usr/bin/env python3
# Checker for probe_quantize_sweep.mojo — reads "r g b index256 index16"
# lines on stdin and compares each against quantize_reference.py.
# Exits 1 on any divergence, 0 with a count on full agreement.

import sys

from quantize_reference import ansi256_to_named16, rgb_to_ansi256

checked = 0
failures = 0
for line in sys.stdin:
    parts = line.split()
    if len(parts) != 5:
        continue
    red, green, blue, got_256, got_16 = (int(p) for p in parts)
    want_256 = rgb_to_ansi256(red, green, blue)
    want_16 = ansi256_to_named16(want_256)
    if got_256 != want_256 or got_16 != want_16:
        failures += 1
        if failures <= 5:
            print(
                f"DIVERGENCE rgb({red},{green},{blue}): "
                f"mojo ({got_256},{got_16}) reference ({want_256},{want_16})"
            )
    checked += 1

print(f"checked {checked} grid points, {failures} divergences")
sys.exit(1 if failures else 0)
