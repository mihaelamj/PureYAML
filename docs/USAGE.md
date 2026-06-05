# PureYAML Usage

PureYAML is a dependency-free Swift package for parsing, emitting, validating,
and typed-converting the YAML subset currently covered by the test corpus.

## Installation

The first release target is 0.1.0. After the tag is published, depend on the
tagged package version:

```swift
.package(url: "https://github.com/mihaelamj/PureYAML.git", .upToNextMinor(from: "0.1.0"))
```

Until that tag exists, use the `main` branch:

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
| Parse a YAML stream into indexed documents | `PureYAML.parseStream(_:)` | `[PureYAML.Stream.Document]` |
| Parse YAML while preserving explicit tags | `PureYAML.parseTagged(_:)` | `PureYAML.Tagged.Node` |
| Parse a YAML stream while preserving explicit tags | `PureYAML.parseTaggedStream(_:)` | `[PureYAML.Tagged.Document]` |
| Construct typed values from tagged nodes | `PureYAML.Tagged.Constructor` | Caller-owned output type |
| Emit YAML from a value tree | `PureYAML.dump(_:options:)` | `String` |
| Emit YAML from stream documents | `PureYAML.dump(_:options:)` with `[PureYAML.Stream.Document]` | `String` |
| Validate a value tree | `PureYAML.validate(_:using:strict:)` | `[PureYAML.Validation.Issue]` or a thrown issue collection |
| Validate stream documents | `PureYAML.validate(_:using:strict:)` with `[PureYAML.Stream.Document]` | `[PureYAML.Stream.Issue]` or a thrown stream issue collection |
| Decode a typed value from YAML | `PureYAML.decode(_:from:)` | `Decodable` value |
| Encode a typed value to a value tree | `PureYAML.encode(_:)` | `PureYAML.Model.Value` |
| Encode a typed value to YAML | `PureYAML.encodeToYAML(_:options:)` | `String` |

PureYAML intentionally does not expose arbitrary `Any` dictionary-and-array load
or dump APIs. Use `Model.Value` for unknown schemas and typed `Codable` for
known schemas.

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

Use `PureYAML.parseStream(_:)` when an input can contain multiple YAML
documents. The result is an array of `PureYAML.Stream.Document` values:

```swift
let documents = try PureYAML.parseStream("""
---
title: First
---
- Swift
- YAML
""")
```

Use `PureYAML.dump(_:)` with `[PureYAML.Stream.Document]` to emit a
multi-document stream. The dumper emits explicit `---` before every document and
preserves the array order rather than sorting by `document.index`:

```swift
let yaml = PureYAML.dump(documents)
```

The same emitter options apply to each document body. Flow collections,
literal-block scalar selection, and complex mapping key emission are delegated to
the single-document dumper.

`PureYAML.parse(_:)` remains the single-document API. It accepts one implicit or
explicit document, including an explicit empty document, and throws
`unsupportedMultiDocumentStream` when a second document is present.

Merge keys are expanded during parsing. Plain `<<` and explicit `!!merge` keys
inherit mapping entries from a mapping or sequence of mappings; local keys
override inherited keys, and duplicate local keys remain visible to validation.
Quoted `"<<":` and explicitly string-tagged `!!str <<` keys remain ordinary
string keys.

If a caller needs a JSON-like dictionary after validation, build that projection
in application code after deciding how duplicate keys, unsupported tags, and
complex keys should behave. Keeping that step outside PureYAML makes the lossy
boundary explicit.

## Tagged Usage

Use `PureYAML.parseTagged(_:)` when the caller needs to preserve explicit YAML
tags for compatibility analysis or project-specific conversion. The tagged
model is separate from `Model.Value` so normal parsing remains small and
dependency-free.
Tagged parsing preserves source shape for diagnostics and compatibility
analysis. Use `parse(_:)` or `parseStream(_:)` when the caller needs semantic
merge-key expansion into `Model.Value`.

```swift
let tagged = try PureYAML.parseTagged("""
payload: !!binary |
  YWJj
custom: !<tag:example.com,2026:thing> {name: Example}
""")

let result = PureYAML.Tagged.Validator().collect(tagged)
```

The default tagged validator reports unsupported built-in tags such as
`!!binary`, `!!timestamp`, `!!set`, `!!omap`, and `!!pairs`. It also reports
built-in tags applied to the wrong node kind, such as `!!seq {name: Example}`.
Project-specific tags are preserved and allowed by default.

Tagged validation supports the same strict and non-strict issue behavior as
ordinary validation. Start from `PureYAML.Tagged.Validator.blank` when a caller
wants only project-specific tag rules.

`PureYAML.parseTaggedStream(_:)` returns indexed tagged documents, and
`PureYAML.Tagged.Validator` can validate those documents with
`PureYAML.Stream.Issue` diagnostics.

PureYAML deliberately does not construct Foundation values for tags such as
`!!timestamp` or `!!binary`. Those tags stay visible in the tagged tree and stay
ordinary strings in `Model.Value`; callers own any `Date`, `Data`, or
domain-specific conversion.

Use `PureYAML.Tagged.Constructor` when the application owns that conversion. A
constructor is empty by default, so unsupported tags fail with an exact
`ConstructionError` instead of silently becoming `Any` dictionaries:

```swift
let value = try PureYAML.Tagged.Constructor<String>()
    .constructingScalar(tag: .init("!Env")) { scalar, _ in
        scalar.rawValue
    }
    .construct(try PureYAML.parseTagged("!Env DATABASE_URL"))
```

Handlers can be registered for scalar, sequence, and mapping nodes. The context
passed to each handler includes the root node, current node, path, and a
recursive `construct(_:at:)` method that keeps nested construction diagnostics
path-aware.

When a caller intentionally wants to drop tag metadata, use the explicit
fallback:

```swift
let model = try PureYAML.Tagged.Constructor<PureYAML.Model.Value>
    .modelValueErasingTags
    .construct(tagged)
```

That fallback preserves mapping order and duplicate keys, then erases scalar,
sequence, mapping, and key tags. It does not run tagged validation implicitly;
call `PureYAML.Tagged.Validator` first when unsupported built-in tags should
block construction.

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

Complex mapping keys are supported in the model layer and can be parsed,
validated, and dumped:

```swift
let value = try PureYAML.parse("""
? [Detroit Tigers, Chicago Cubs]
:
  - 2001-07-23
""")

if case let .mapping(mapping) = value {
    let firstKey = mapping.pairs.first?.keyNode
}
```

Keyed `Codable` remains string-keyed. Sequence and mapping keys stay visible in
`PureYAML.Model.Value`, but are skipped by `KeyedDecodingContainer.allKeys` and
cannot be read as Swift coding keys. Inspect `Model.Value` directly when a
caller needs those keys.

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

Stream validation preserves document indexes without changing document-local
paths:

```swift
let documents = try PureYAML.parseStream("""
---
title: First
title: Second
---
routes:
  - name: Users
    name: People
""")

do {
    try PureYAML.validate(documents)
} catch let collection as PureYAML.Stream.Issue.Collection {
    print(collection.description)
}
```

The issue descriptions include `document[0]`, `document[1]`, and so on, while
the nested validation path still describes the location inside that document.

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
