# Probe: can a pure resolver over String inputs run in the compile-time
# interpreter? If yes, applications can bake a static ColorLevel with zero
# runtime cost — the "static configuration" story for the env-free API.
# Run: pixi run mojo run .probe/probe_comptime_resolve.mojo


def _resolve(*, is_tty: Bool, term: String = "") -> UInt8:
    if not is_tty:
        return UInt8(0)
    if term == "dumb":
        return UInt8(0)
    if term.endswith("256color"):
        return UInt8(2)
    if term.byte_length() > 0:
        return UInt8(1)
    return UInt8(0)


comptime _STATIC_LEVEL: UInt8 = _resolve(is_tty=True, term="xterm-256color")


def main():
    print(Int(_STATIC_LEVEL))  # expected: 2
    print(Int(_resolve(is_tty=False, term="xterm")))  # expected: 0
