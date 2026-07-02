# Probe: what must a custom type implement to conform to Writer?
# Run: pixi run mojo run .probe/probe_custom_writer.mojo
# EXPECTED TO FAIL on round 1 — the compiler enumerates the unimplemented
# trait requirements; that list is the finding. Round 2 implements them.


struct ByteSink(Writer):
    var storage: List[UInt8]

    def __init__(out self):
        self.storage = List[UInt8]()

    # Finding (round 1): Writer requires exactly one method — this one,
    # declared in std/format. Everything else is derived from it.
    def write_string(mut self, string: StringSlice):
        self.storage.extend(string.as_bytes())


def main():
    var sink = ByteSink()
    sink.write_string("ok")  # the requirement, called directly
    sink.write("/", 42)  # the derived variadic form — question: available?
    print(len(sink.storage))  # expected: 5 — "ok/42"
