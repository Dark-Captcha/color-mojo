# Probe: byte-oriented writing — does `write_bytes` exist on Writer, what does
# it accept, and does List[UInt8] itself conform to Writer as a sink?
# Run: pixi run mojo run .probe/probe_writer_byte_sinks.mojo
# A compile error here is a finding: it names the real signature to use.


def emit_bytes[W: Writer](mut writer: W):
    var raw = List[UInt8]()
    raw.append(UInt8(0x6F))  # 'o'
    raw.append(UInt8(0x6B))  # 'k'
    writer.write_bytes(Span(raw))


def main():
    var text = String("")
    emit_bytes(text)
    print(text)  # expected: "ok"

    var sink = List[UInt8]()
    emit_bytes(sink)  # question: does List[UInt8] conform to Writer?
    print(len(sink))  # expected: 2
