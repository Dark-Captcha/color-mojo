# Probe: a `def` passed as a compile-time parameter — the shape a table-free
# test runner needs (`run_case[some_test]("name")`).
# Run: pixi run mojo run .probe/probe_function_as_parameter.mojo
# A compile error here is a finding: it reveals whether function values are
# legal parameters and how their type is spelled.


def sample_case() raises:
    print("sample_case ran")


# Finding (round 1): `case` is a reserved keyword — parameter renamed.
def run_case[test_function: def () raises](name: String):
    try:
        test_function()
        print("PASS", name)
    except error:
        print("FAIL", name)


def main():
    run_case[sample_case]("sample_case")
