# Probe: a StringSlice view over stack storage (InlineArray) — the
# zero-allocation open-sequence path for paint_into.
# Run: pixi run mojo run .probe/probe_stringslice_from_stack.mojo
# A compile error names the real constructor/span syntax; that is the finding.


def main():
    var storage = InlineArray[UInt8, 8](uninitialized=True)
    storage[0] = UInt8(0x6F)  # 'o'
    storage[1] = UInt8(0x6B)  # 'k'
    var view = StringSlice(unsafe_from_utf8=Span(storage)[0:2])
    print(view)  # expected: ok
