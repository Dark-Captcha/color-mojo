# Probe: a module-level comptime InlineArray[UInt8, 256] built by a loop —
# the shape of a compile-time quantization table. Checks (a) the comptime
# interpreter evaluates the builder, (b) runtime indexing works, (c) a
# lookup loop runs at table speed (rodata), not rebuild-per-call speed.
# Run: pixi run mojo run .probe/probe_comptime_table.mojo

from std.time import perf_counter_ns


def _build_table() -> InlineArray[UInt8, 256]:
    var table = InlineArray[UInt8, 256](uninitialized=True)
    for index in range(256):
        table[index] = UInt8((index * 7 + 3) % 251)
    return table


comptime _TABLE: InlineArray[UInt8, 256] = _build_table()


def main():
    # Correctness: spot values.
    print(Int(_TABLE[0]))  # 3
    print(Int(_TABLE[16]))  # (16*7+3)%251 = 115
    print(Int(_TABLE[255]))  # (255*7+3)%251 = 31

    # Speed: 1M lookups. Table-in-rodata is ~1 ns/lookup; a per-call
    # materialization of 256 bytes would show tens of ns.
    var total = 0
    var start = perf_counter_ns()
    for index in range(1_000_000):
        total += Int(_TABLE[index & 255])
    var stop = perf_counter_ns()
    print("guard", total)
    print("ns/lookup", Float64(stop - start) / 1_000_000.0)
