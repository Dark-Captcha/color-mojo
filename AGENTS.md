# Repository Instructions

## Scope

- Keep `color` dependency-free and pure Mojo.
- Preserve the seven-name package-root public surface unless a release explicitly changes it.
- Keep terminal detection in `ColorLevel` and rendering policy in `Painter`/`Style`.
- Treat `_internal` modules as private implementation details.

## Toolchain

- Use the Pixi environment and locked Mojo nightly from `pixi.toml`.
- Run `pixi run format` after editing Mojo files.
- Run `pixi run test`, `pixi run example`, and `pixi run benchmark` before release changes.
- Validate public documentation with `pixi run doc`.

## Engineering Rules

- Follow `mojo format` output and existing module naming.
- Explicitly import every used symbol; avoid wildcard and transitive imports.
- Public modules, types, fields, and functions require Mojo docstrings.
- Preserve ownership and lifecycle behavior; avoid implicit copies of allocating values.
- Add focused tests for every behavior change and benchmark evidence for performance claims.
- Do not add platform claims that CI and the Pixi lock do not exercise.

## Contributions

- Keep commits atomic and use imperative titles.
- Never commit credentials, generated environments, or benchmark corpora.
- Upstream Modular contributions require prior maintainer agreement for non-trivial work, signed commits, and an `Assisted-by: AI` disclosure when applicable.
