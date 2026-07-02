# Probe: the Writer trait as a generic bound — `def emit[W: Writer](mut writer: W)`.
# Run: pixi run mojo run .probe/probe_writer_trait.mojo
# Question answered: is `Writer` nameable as a parameter bound, and does the
# stdlib String conform (accumulating writes into a String)?


def emit[W: Writer](mut writer: W):
    writer.write("alpha ")
    writer.write(42)


def main():
    var target = String("")
    emit(target)
    print(target)  # expected: "alpha 42"
