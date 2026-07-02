# decimal — integer to ASCII decimal for the SGR parameter range (0..255,
# hard ceiling 999). The two-digit lookup table is the fmt / Rust std / Go
# runtime technique: every value 0..99 stores its two ASCII digits adjacently,
# so a pair emits as one indexed read instead of a divide-and-modulo pair.
# Reference: Andrei Alexandrescu, "Three Optimization Tips for C++",
# CppCon 2014.


comptime DIGIT_PAIRS: StaticString = (
    "00010203040506070809"
    "10111213141516171819"
    "20212223242526272829"
    "30313233343536373839"
    "40414243444546474849"
    "50515253545556575859"
    "60616263646566676869"
    "70717273747576777879"
    "80818283848586878889"
    "90919293949596979899"
)


@always_inline
def write_decimal[
    capacity: Int
](mut buffer: InlineArray[UInt8, capacity], offset: Int, value: Int) -> Int:
    """Write `value` (0..999) as ASCII into `buffer` starting at byte
    `offset`; return the offset just past the last digit. The caller
    guarantees the digits fit under `capacity` — emission targets a
    comptime-bounded stack buffer sized for the worst case, so no runtime
    check is spent here.

    Taking the `InlineArray` directly keeps a concrete pointer origin —
    passing raw pointers across this boundary would erase the origin, which
    the compiler deprecates (.probe/SYNTAX.md)."""
    var pointer = buffer.unsafe_ptr()
    var table = DIGIT_PAIRS.as_bytes()
    if value < 10:
        pointer[offset] = UInt8(ord("0")) + UInt8(value)
        return offset + 1
    if value < 100:
        var pair = value + value
        pointer[offset] = table[pair]
        pointer[offset + 1] = table[pair + 1]
        return offset + 2
    var hundreds = value // 100
    var remainder = value - hundreds * 100
    var pair = remainder + remainder
    pointer[offset] = UInt8(ord("0")) + UInt8(hundreds)
    pointer[offset + 1] = table[pair]
    pointer[offset + 2] = table[pair + 1]
    return offset + 3
