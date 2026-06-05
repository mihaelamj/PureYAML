# PureYAML Conventions

PureYAML is a dependency-free Swift YAML package. The rules here keep it
portable, testable, and usable from OpenAPIDoctor and future browser/WASI tools.

## Language

Swift only. Do not add external dependencies, C sources, generated parser
runtimes, JavaScript tooling, or platform frameworks to the public package.
Yams and CYaml may be studied and attributed, but their source must not be copied
into `Sources/`.

## Package Shape

PureYAML is a root Swift package:

- `Package.swift`
- `Sources`
- `Tests/PureYAMLTests`

No `Packages/` folder.

## Namespacing

Every public type lives under `PureYAML` and mirrors its folder:

- `PureYAML.Model.Value`
- `PureYAML.Model.Mapping`
- `PureYAML.Parsing.Parser`
- `PureYAML.Emitting.Dumper`

The root file is a namespace map. Concrete public types are declared in
extensions on leaf namespaces.

## Portability

The library target must build on:

- macOS
- Linux
- `wasm32-unknown-wasip1`

Prefer standard-library code in the core. If Foundation ever becomes necessary,
document why and test Linux/WASI before merging.

## Testing

Use Swift Testing. Parser and emitter changes require behavioral tests against
the public API.

## Verification

Before claiming completion, run:

```sh
bash scripts/check-style.sh
bash scripts/check-namespacing.sh
bash scripts/check-forbidden-patterns.sh
bash scripts/check-changelog-touched.sh
swiftformat . --config .swiftformat --lint
swiftlint --config .swiftlint.yml --strict
swift build
swift test
bash scripts/check-wasm.sh
```
