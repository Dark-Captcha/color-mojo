# Probe: constructing a String from a UInt8 buffer.
# Run: pixi run mojo run .probe/probe_string_from_bytes.mojo
# Round 1 deliberately omits `raises` on main — if the compiler objects that
# the constructor can raise, the objection itself is the finding (the
# validating constructor raises). Round 2 adds `raises` and must print "ok".


# Finding (round 1): `String(from_utf8=...)` raises — the validating form.
# Round 2 verifies both forms run: validating (with raises) and the
# non-validating `unsafe_from_utf8`, which the overload probe revealed.
def main() raises:
    var buffer = List[UInt8]()
    buffer.append(UInt8(0x6F))  # 'o'
    buffer.append(UInt8(0x6B))  # 'k'
    var validated = String(from_utf8=buffer)
    print(validated)  # expected: "ok"

    var trusted = String(unsafe_from_utf8=buffer)
    print(trusted)  # expected: "ok" — no validation, caller guarantees UTF-8

