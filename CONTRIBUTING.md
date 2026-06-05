# Contributing to PureYAML

Thanks for your interest in PureYAML.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Project Shape

PureYAML is a root Swift package:

```text
PureYAML/
├── Package.swift
├── Sources/PureYAML/
├── Tests/PureYAMLTests/
├── docs/
└── scripts/
```

Do not create a `Packages/` folder for this repo.

## Rules

- Pure Swift only.
- No external SwiftPM dependencies.
- No C-backed parser target in the public package.
- Every public type lives under the `PureYAML` namespace tree.
- Build and test on macOS, Linux, and WASI.

## Setup

```sh
git config core.hooksPath .githooks
swift build
swift test
```

Install SwiftFormat and SwiftLint if they are not already available:

```sh
brew install swiftformat swiftlint
```

## Verification

Before opening a PR or saying a change is ready, run:

```sh
bash scripts/check-style.sh
bash scripts/check-namespacing.sh
bash scripts/check-changelog-touched.sh
swiftformat . --config .swiftformat --lint
swiftlint --config .swiftlint.yml --strict
swift build
swift test
bash scripts/check-wasm.sh
```

## Commits

Use Conventional Commits:

```text
<type>(<scope>): summary
```

Examples:

- `feat(parser): add block sequence parsing`
- `test(emitter): cover quoted scalar dumping`
- `ci(wasm): add wasi build gate`

Do not include AI attribution. Do not use em dashes.

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT license](LICENSE).
