# Probe: the immutable-builder shape used by a fluent style type — a
# no-argument constructor plus chained methods, each returning a fresh value.
# Run: pixi run mojo run .probe/probe_fluent_construction.mojo


struct Counter(Copyable, Movable):
    var count: Int

    def __init__(out self):
        self.count = 0

    def bumped(self) -> Counter:
        # Finding (round 1): returning a local by value demands an explicit
        # move — implicit copy requires the ImplicitlyCopyable trait.
        var next = Counter()
        next.count = self.count + 1
        return next^


def main():
    var counter = Counter().bumped().bumped()
    print(counter.count)  # expected: 2
