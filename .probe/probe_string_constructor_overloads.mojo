# Probe: enumerate every String constructor the compiler knows.
# Run: pixi run mojo run .probe/probe_string_constructor_overloads.mojo
# EXPECTED TO FAIL — the bogus keyword forces the compiler to print the full
# overload candidate list; that error text is the result being probed for.
# Looking for a non-validating (non-raising) bytes-to-String form, for
# example `unsafe_from_utf8`.


def main():
    var buffer = List[UInt8]()
    var text = String(no_such_keyword_on_purpose=buffer^)
    print(text)
