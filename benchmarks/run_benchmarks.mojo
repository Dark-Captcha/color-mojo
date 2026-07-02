# benchmarks/run_benchmarks.mojo — latency for color-mojo's hot paths.
# Run: pixi run benchmark. Protocol: N calls per path, ns/call reported,
# median of nine runs recorded in PERF.md. Nothing here touches the process
# environment — every input is held explicitly, the same purity contract as
# the library itself — so each number describes exactly the path its label
# names.

from std.time import perf_counter_ns

from color import (
    Color,
    ColorLevel,
    Painter,
    Style,
    strip_escapes,
    visible_width,
)


comptime N: Int = 200_000


def bench_style_named() raises:
    var style = Style().foreground(Color.RED)
    var sink = String("")
    var start = perf_counter_ns()
    for _ in range(N):
        sink = style.paint("oops")
    var stop = perf_counter_ns()
    _report("Style.paint named          ", start, stop, sink.byte_length())


def bench_style_combined() raises:
    var style = (
        Style().bold().italic().foreground(Color.YELLOW).background(Color.BLACK)
    )
    var sink = String("")
    var start = perf_counter_ns()
    for _ in range(N):
        sink = style.paint("warn")
    var stop = perf_counter_ns()
    _report("Style.paint combined       ", start, stop, sink.byte_length())


def bench_style_rgb() raises:
    var style = Style().foreground(Color.rgb(red=255, green=100, blue=0))
    var sink = String("")
    var start = perf_counter_ns()
    for _ in range(N):
        sink = style.paint("rgb")
    var stop = perf_counter_ns()
    _report("Style.paint rgb            ", start, stop, sink.byte_length())


def bench_painter_downgrade() raises:
    var painter = Painter.from_level(ColorLevel.ANSI256)
    var style = Style().foreground(Color.rgb(red=255, green=100, blue=0))
    var sink = String("")
    var start = perf_counter_ns()
    for _ in range(N):
        sink = painter.paint(style, "rgb")
    var stop = perf_counter_ns()
    _report("Painter.paint rgb->256     ", start, stop, sink.byte_length())


def bench_painter_downgrade16() raises:
    var painter = Painter.from_level(ColorLevel.ANSI16)
    var style = Style().foreground(Color.rgb(red=255, green=100, blue=0))
    var sink = String("")
    var start = perf_counter_ns()
    for _ in range(N):
        sink = painter.paint(style, "rgb")
    var stop = perf_counter_ns()
    _report("Painter.paint rgb->16      ", start, stop, sink.byte_length())


def bench_painter_plain() raises:
    var painter = Painter.plain()
    var style = Style().foreground(Color.rgb(red=255, green=100, blue=0))
    var sink = String("")
    var start = perf_counter_ns()
    for _ in range(N):
        sink = painter.paint(style, "rgb")
    var stop = perf_counter_ns()
    _report("Painter.paint disabled     ", start, stop, sink.byte_length())


def bench_paint_into() raises:
    var style = Style().bold().foreground(Color.ansi256(208))
    var guard = 0
    var start = perf_counter_ns()
    for _ in range(N):
        var sink = String("")
        style.paint_into(sink, "orange")
        guard += sink.byte_length()
    var stop = perf_counter_ns()
    _report("Style.paint_into fresh sink", start, stop, guard)


def bench_resolve() raises:
    # True per-call cost: flip one byte of colorterm per iteration
    # ("truecolor" resolves TRUECOLOR, "uruecolor" falls through to TERM),
    # so the pure call cannot hoist and both outcome paths execute. With
    # held signals the optimizer removes the loop-invariant call entirely,
    # and comptime signals bake the tier into the binary (PERF.md).
    var colorterm = String("truecolor")
    var term = String("xterm")
    var empty = String("")
    var pointer = colorterm.unsafe_ptr_mut()
    var tiers = 0
    var start = perf_counter_ns()
    for iteration in range(N):
        pointer[0] = UInt8(ord("t")) + UInt8(iteration & 1)
        var level = ColorLevel.resolve(
            is_tty=True,
            no_color=empty,
            force_color=empty,
            clicolor=empty,
            clicolor_force=empty,
            colorterm=colorterm,
            term=term,
        )
        tiers += 3 if level == ColorLevel.TRUECOLOR else 1
    var stop = perf_counter_ns()
    _report("ColorLevel.resolve changing", start, stop, tiers)


def bench_strip_short() raises:
    var painted = Style().bold().foreground(Color.ansi256(208)).paint("ALERT")
    var sink = String("")
    var start = perf_counter_ns()
    for _ in range(N):
        sink = strip_escapes(painted)
    var stop = perf_counter_ns()
    _report("strip_escapes short        ", start, stop, sink.byte_length())


def bench_strip_long() raises:
    var segment = Style().bold().foreground(Color.RED).paint("ERROR")
    var line = (
        segment
        + " connection lost at "
        + segment
        + " 10.0.0.5:443 retry="
        + segment
        + " \x1b]8;;https://example.test\x07runbook\x1b]8;;\x07"
    )
    var sink = String("")
    var start = perf_counter_ns()
    for _ in range(N):
        sink = strip_escapes(line)
    var stop = perf_counter_ns()
    _report("strip_escapes long+OSC     ", start, stop, sink.byte_length())


def bench_visible_width() raises:
    var painted = Style().bold().foreground(Color.RED).paint("café ALERT")
    var total = 0
    var start = perf_counter_ns()
    for _ in range(N):
        total += visible_width(painted)
    var stop = perf_counter_ns()
    _report("visible_width utf8         ", start, stop, total)


def _report(name: StaticString, start: UInt, stop: UInt, guard: Int) raises:
    print(
        name,
        ":",
        Float64(stop - start) / Float64(N),
        "ns/call (guard=",
        guard,
        ")",
    )


def main() raises:
    print("color-mojo benchmarks (N =", N, ")")
    bench_style_named()
    bench_style_combined()
    bench_style_rgb()
    bench_painter_downgrade()
    bench_painter_downgrade16()
    bench_painter_plain()
    bench_paint_into()
    bench_resolve()
    bench_strip_short()
    bench_strip_long()
    bench_visible_width()
