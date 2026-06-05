# PureYAML Usage

PureYAML is a dependency-free Swift package for parsing, emitting, validating,
and typed-converting the YAML subset currently covered by the test corpus.

## Installation

Until the first tagged release, use the `main` branch:

```swift
.package(url: "https://github.com/mihaelamj/PureYAML.git", branch: "main")
```

Add the product to the target that reads or writes YAML:

```swift
.product(name: "PureYAML", package: "PureYAML")
```

Then import the library:

```swift
import PureYAML
```

`Package.swift` for PureYAML itself keeps `dependencies: []`. Consumers do not
need C libraries, generated parser files, JavaScript tooling, or Foundation-only
support code to use the library target.

## Public Entry Points

The README examples are mirrored in `Tests/DocumentationExampleTests.swift`.
Those tests are the executable contract for the short-form examples.

| Need | API | Result |
|---|---|---|
| Parse YAML into an ordered value tree | `PureYAML.parse(_:)` | `PureYAML.Model.Value` |
| Emit YAML from a value tree | `PureYAML.dump(_:options:)` | `String` |
| Validate a value tree | `PureYAML.validate(_:using:strict:)` | `[PureYAML.Validation.Issue]` or a thrown issue collection |
| Decode a typed value from YAML | `PureYAML.decode(_:from:)` | `Decodable` value |
| Encode a typed value to a value tree | `PureYAML.encode(_:)` | `PureYAML.Model.Value` |
| Encode a typed value to YAML | `PureYAML.encodeToYAML(_:options:)` | `String` |

## Model Usage

Use `PureYAML.Model.Value` when the caller needs to inspect YAML structure,
preserve mapping order, validate duplicate keys, or handle YAML that does not map
cleanly to a Swift `Codable` type.

The model currently represents:

- `null`
- booleans
- integers
- doubles
- strings
- ordered mappings
- sequences

Mappings preserve insertion order and retain duplicate keys. That is deliberate:
validation can report duplicate-key diagnostics instead of losing information by
collapsing a mapping into a Swift dictionary too early.

## Typed Conversion

Use typed conversion when the YAML shape is already known. Current coverage
includes:

- scalar `Decodable` and `Encodable` values;
- keyed mapping-backed structs;
- optional scalar fields;
- nested keyed structs;
- unkeyed sequences;
- nested sequences;
- keyed structs with sequence properties;
- dictionary-like string-keyed mappings where YAML semantics allow them;
- keyed super coders and default `super` coders.

Typed decoding runs the default validator first. Duplicate mapping keys are
reported before Swift `Decodable` construction starts.

## Emitting Options

The default dumper emits deterministic block-style YAML with quoted strings.
Callers can opt into:

- conservative plain strings with `.plainWhenSafe`;
- safe literal block scalars for multiline strings with
  `.literalBlockWhenMultiline`;
- compact flow collections with `collectionStyle: .flow`.

Literal block emission is conservative. If a multiline string would not
round-trip through the current parser, the dumper keeps it as a quoted scalar.

## Validation

The default validator rejects duplicate mapping keys anywhere in the value tree.
Validation issues include:

- severity;
- reason;
- path.

Strict validation treats warnings as failures. Non-strict validation returns
warnings but still throws when errors are present.

Use `PureYAML.Validation.Validator.blank` when the caller wants only
project-specific validation rules.

## Cross-Platform Verification

Before relying on a migration, run the same gates used by the repository:

```sh
bash scripts/check-all.sh
bash scripts/check-linux.sh
bash scripts/check-wasm.sh
```

`scripts/check-all.sh` includes style, namespacing, forbidden-pattern,
changelog, roadmap, SwiftFormat, SwiftLint, host build, host tests, Linux build
and test, and WASM build checks. The explicit Linux and WASM scripts are useful
when recording release or migration evidence.

## Support Boundaries

PureYAML is not yet a complete YAML 1.2 implementation. Before replacing another
YAML stack, read [MIGRATION.md](MIGRATION.md) and compare your input corpus with
the supported and unsupported behavior listed there.
