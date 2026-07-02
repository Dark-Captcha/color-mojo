# Probe: InlineArray as the single write destination for SGR emission —
# raw pointer access on a `mut` parameter, memcpy in and out, a
# capacity-parameterized helper (finding #10: take the pointer inside the
# helper so the origin stays concrete), and the StringSlice view on top.
# Run: pixi run mojo run .probe/probe_inline_array_writer.mojo

from std.memory import memcpy


def _write_digits[
    capacity: Int
](mut buffer: InlineArray[UInt8, capacity], offset: Int, value: Int) -> Int:
    var pointer = buffer.unsafe_ptr()
    pointer[offset] = UInt8(ord("0")) + UInt8(value // 10)
    pointer[offset + 1] = UInt8(ord("0")) + UInt8(value % 10)
    return offset + 2


def main():
    var buffer = InlineArray[UInt8, 64](uninitialized=True)

    # Direct pointer stores through the helper.
    var offset = _write_digits(buffer, 0, 31)

    # memcpy from a StaticString into the stack buffer.
    comptime tail: StaticString = ";1m"
    memcpy(
        dest=buffer.unsafe_ptr() + offset,
        src=tail.as_bytes().unsafe_ptr(),
        count=3,
    )
    offset += 3

    # View without allocation, then memcpy out into an exact-length String.
    var view = StringSlice(unsafe_from_utf8=Span(buffer)[0:offset])
    print(view)  # expected: 31;1m

    var result = String(unsafe_uninit_length=offset)
    memcpy(
        dest=result.unsafe_ptr_mut(),
        src=buffer.unsafe_ptr(),
        count=offset,
    )
    print(result)  # expected: 31;1m
