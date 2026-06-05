# Agent Guide

Guidance for anyone writing code in PureYAML.

## Rule Loading

At the start of a session, read this file and the rules under `docs/rules/` that
match the task. Confirm by replying with `rules-loaded` and name the files you
loaded.

For code changes, load at minimum:

- `docs/rules/code-style.md`
- `docs/rules/namespacing.md`
- `docs/rules/cross-platform.md`
- `docs/rules/testing.md`
- `docs/rules/verification.md`
- `docs/rules/commits.md`
- `docs/rules/research-compatibility.md`

## What PureYAML Is

PureYAML is a dependency-free YAML package written entirely in Swift.

The package must stay:

- pure Swift
- root Swift package layout, with `Package.swift` at repository root
- dependency-free
- Linux-compatible
- WebAssembly/WASI-compatible
- namespaced under `PureYAML`

The private `PureYAMLResearch` repo is for studying Yams and libyaml behavior.
Do not copy C code or upstream Yams source into this public package.
Keep attribution in `ATTRIBUTION.md` accurate when compatibility work references
Yams or CYaml behavior.

Compatibility work must start from that research source. Before changing parser,
emitter, validation, or typed conversion behavior, inspect the matching
PureYAMLResearch source or fixture and use it only to define behavior and tests.

## Namespace Rules

Every public type lives under the `PureYAML` namespace tree and mirrors its
folder:

- `Sources/Model/Value.swift` declares `PureYAML.Model.Value`
- `Sources/Parsing/Parser.swift` declares `PureYAML.Parsing.Parser`
- `Sources/Emitting/Dumper.swift` declares `PureYAML.Emitting.Dumper`
- `Sources/Validation/Validator.swift` declares `PureYAML.Validation.Validator`

No top-level public concrete types except the root `public enum PureYAML`.

## Dependency Rules

`Package.swift` must keep `dependencies: []`.

Do not add external packages, C targets, system libraries, Foundation-only
workarounds, JavaScript tooling, or generated parser dependencies without an
explicit maintainer decision.

## Verification

Before claiming a change is complete, run and cite:

```sh
bash scripts/check-style.sh
bash scripts/check-namespacing.sh
bash scripts/check-forbidden-patterns.sh
bash scripts/check-changelog-touched.sh
swiftformat . --config .swiftformat --lint
swiftlint --config .swiftlint.yml --strict
swift build
swift test
bash scripts/check-linux.sh
bash scripts/check-wasm.sh
```

Enable local hooks:

```sh
git config core.hooksPath .githooks
```
