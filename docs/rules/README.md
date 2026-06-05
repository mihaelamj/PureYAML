# PureYAML Rules

Load these rules before changing code:

- `code-style.md`
- `namespacing.md`
- `cross-platform.md`
- `testing.md`
- `verification.md`
- `commits.md`

Project-specific overrides:

- PureYAML uses a root `Package.swift`.
- Sources live directly under `Sources`.
- Tests live in `Tests/PureYAMLTests`.
- `Package.swift` must keep `dependencies: []`.
- Public API must live under the `PureYAML` namespace tree.
- The package must build on macOS, Linux, and WASI.

The broader rule files are retained for detailed guidance. When they include
generic examples, apply the PureYAML-specific overrides above.
