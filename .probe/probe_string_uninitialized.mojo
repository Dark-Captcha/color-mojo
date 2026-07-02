# Probe: String(*, unsafe_uninit_length=n) — allocate a String of length n,
# then fill its bytes directly. The candidate zero-copy render target.
# Run: pixi run mojo run .probe/probe_string_uninitialized.mojo
# The pointer accessor name below is a guess; a compile error names the
# real one, which is the finding.


def main():
    var text = String(unsafe_uninit_length=2)
    var pointer = text.unsafe_ptr_mut()
    pointer[0] = UInt8(0x6F)  # 'o'
    pointer[1] = UInt8(0x6B)  # 'k'
    print(text)  # expected: "ok"
