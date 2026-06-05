# PureYAML Design

| Field | Value |
|---|---|
| Status | draft |
| Created | 2026-06-05 |
| Last revised | 2026-06-05 |

## Purpose

PureYAML exists to provide a dependency-free YAML implementation in Swift that
can build on macOS, Linux, and WebAssembly/WASI. The first user is
OpenAPIDoctor, which needs YAML parsing and mutation without a C-backed parser
blocking browser deployment.

## Goals

- Parse a useful YAML subset with no external dependencies.
- Preserve mapping order.
- Emit YAML from the same model.
- Validate YAML structures with path-aware issues.
- Build the library target for `wasm32-unknown-wasip1`.
- Grow toward Yams-compatible behavior through tests, not source copying.

## Non-Goals

- No C source in the public package.
- No external SwiftPM dependency.
- No JavaScript parser or build-time generator.
- No arbitrary `Any` load or dump API that collapses YAML mappings into
  dictionary-shaped values before validation.
- No claim of complete YAML 1.2 coverage until the test corpus proves it.

## Current Architecture

```text
PureYAML
├── Model
│   ├── Value
│   ├── Mapping
│   └── Pair
├── Parsing
│   ├── Parser
│   ├── Reader
│   ├── Scanner
│   ├── Token
│   ├── TokenCursor
│   ├── TokenEventParser
│   ├── EventComposer
│   ├── Event
│   ├── Mark
│   └── ParseError
├── Emitting
│   ├── Dumper
│   └── Options
├── Decoding
│   ├── Decoder
│   └── Error
├── Encoding
│   ├── Encoder
│   └── Error
├── Stream
│   ├── Document
│   ├── Issue
│   └── Result
├── Tagged
│   ├── Node
│   ├── Document
│   ├── Tag
│   ├── Validator
│   └── Rule
└── Validation
    ├── Validator
    ├── Rule
    ├── Issue
    └── Path
```

`PureYAML.parse(_:)`, `PureYAML.parseStream(_:)`, and `PureYAML.dump(_:)` are
convenience entry points. Parsing runs through the scanner, token-event parser,
and event composer before returning `PureYAML.Model.Value` for one document or
`PureYAML.Stream.Document` values for a stream. The implementation lives in
namespaced parser, dumper, scalar typed coder, stream, tagged-node, and
validator types.

## First Milestone

The initial parser supports:

- block mappings
- block sequences
- ordered mappings
- strings
- ints
- doubles
- bools
- nulls
- quoted strings
- comments outside quoted strings
- flow sequences and mappings
- literal and folded block scalars
- anchors and aliases
- merge-key expansion for mappings and sequences of mappings
- complex mapping keys as sequence or mapping values
- YAML directives, document markers, and multi-document streams
- explicit built-in scalar tags for strings, integers, floats, booleans, and
  nulls
- tag-preserving parse APIs for scalar and collection tags

The parser layer also has an internal event contract. `Parsing.Event` can
represent stream, document, scalar, sequence, mapping, and alias events, with
marks plus scalar and collection styles. Anchors and tags are carried as event
metadata so the later scanner/composer work can add YAML feature coverage
without changing the event shape.

The parser layer now also has an internal reader/scanner/event contract.
`Parsing.Reader` advances through Swift `String` input while tracking UTF-8 byte
indexes, lines, and columns. `Parsing.Scanner` emits lexical `Parsing.Token`
values for comments, indentation, block entries, mapping indicators, flow
delimiters, quoted scalar starts, block scalar headers, anchors, aliases, tags,
YAML directives, document markers, and source mark ranges. `Parsing.Scanner`
also expands tag handles from `%TAG` directives before emitting tag tokens.
`Parsing.TokenEventParser` consumes that token stream and emits `Parsing.Event`
values for block collections, flow collections, aliases, anchors, tags, and
scalars. `Parsing.EventComposer` consumes those events into
`PureYAML.Model.Value`, preserving ordered mapping pairs, block scalar text,
alias-resolved values, and explicit built-in scalar tags where the current model
can represent them.

`PureYAML.parse(_:)` remains a single-document API and rejects a second document
with `unsupportedMultiDocumentStream`. `PureYAML.parseStream(_:)` parses all
documents in the stream, including empty explicit documents as `null`, and
returns `PureYAML.Stream.Document` values with stable zero-based indexes.
`PureYAML.dump(_:)` accepts those stream documents and emits explicit `---`
document starts in the caller-provided array order. Each document body is
rendered through the same dumper used for single-document values, so block,
flow, literal scalar, and complex-key output policies stay centralized.

`PureYAML.parseTagged(_:)` and `PureYAML.parseTaggedStream(_:)` reuse the same
scanner and event parser but compose `PureYAML.Tagged.Node` values that preserve
explicit tags on scalar, sequence, and mapping nodes. Tagged parsing deliberately
does not construct Foundation values for `!!timestamp` or `!!binary`, and
project-specific tags are preserved for caller-owned conversion. It preserves
source shape for diagnostics; normal parsing is the semantic surface that
expands merge keys into
`Model.Value`. `PureYAML.Tagged.Validator` reports
unsupported built-in tags and built-in tags applied to the wrong node kind with
the same path and stream issue types used by the main validator.

`PureYAML.Tagged.Constructor<Output>` is the explicit construction boundary for
projects that want to turn tagged nodes into domain values. It starts empty,
registers handlers by exact tag and node kind, and reports path-aware
`ConstructionError` values when no handler exists or a tag appears on the wrong
node kind. Handler context carries the root node, current subject, path, and a
recursive construction method so nested conversion keeps exact diagnostics. The
model fallback is deliberately named `modelValueErasingTags`: it preserves
mapping order and duplicate keys, then erases tag metadata only when the caller
has opted into that lossy boundary.

Mappings are ordered pairs. String keys remain the common path through
`Model.Pair.key`, `Model.Mapping` string lookup, validation dot/bracket paths,
and keyed `Codable`. Complex keys are represented by `Model.Key` and stored on
each pair as `Model.Pair.keyNode`. Sequence and mapping keys stay visible for
validation, dumping, and model inspection; they are not silently flattened into
Swift dictionary keys. This mirrors the reference behavior that treats mapping
keys as nodes, while keeping PureYAML's public typed-conversion boundary
string-keyed and dependency-free.

The complex-key path contract is deterministic. Simple string keys keep the
existing `.key` path rendering. Sequence and mapping keys use an explicit
complex-key path component whose description is derived from the same stable
flow YAML representation used by duplicate-key diagnostics. That keeps paths
unambiguous even for YAML states that ordinary loaders collapse or cannot
represent in native dictionaries.

The dumper emits deterministic YAML from the model. The default policy is
block-style collections with quoted strings. `Emitting.Options` can opt into
conservative plain scalars, safe literal block scalars for multiline strings,
and flow-style collections. Literal block scalar emission is intentionally
limited to strings whose lines round-trip through the current parser; other
multiline strings stay quoted. Flow collections always use inline scalars.
Complex mapping keys emit as explicit YAML keys in block or flow style.

The validator traverses parsed YAML values and reports path-aware issues. The
default rule rejects duplicate mapping keys. Callers can compose custom rules on
top of the default validator or start from `Validation.Validator.blank` for
project-specific checks only. Strict validation treats warnings as failures;
non-strict validation returns warnings while still throwing for errors. The
validation corpus pins exact issue paths, descriptions, severity splits,
strict/non-strict behavior, rule traversal order, and duplicate-key diagnostics.
The stream validation API wraps document-local issues in `PureYAML.Stream.Issue`
so callers keep both the document index and the exact path inside that document.

Typed conversion supports scalar single-value Decodable and Encodable values,
keyed mapping-backed structs with scalar, optional scalar, nested keyed struct,
and sequence fields, plus unkeyed sequences with scalar elements, optional
elements, nested sequences, and keyed mapping elements. Keyed `Codable` is
deliberately string-keyed: complex mapping keys remain available in
`Model.Value`, but do not appear in `allKeys`, `contains(_:)`, or keyed property
lookup. `PureYAML.decode(_:from:)`, `PureYAML.encode(_:)`, and
`PureYAML.encodeToYAML(_:)` validate input shapes and throw exact path-aware
typed coding errors.

Typed decoding runs default validation before Swift `Decodable` construction.
That keeps ambiguous YAML states, such as duplicate mapping keys, from being
silently collapsed by keyed property lookup.

## Rejected API Shape: Arbitrary Any

PureYAML does not provide a public arbitrary `Any` loader or dumper. Unknown YAML
must stay in `PureYAML.Model.Value`; known YAML should use typed `Codable`.

This is a deterministic validation decision. A Swift dictionary-shaped value
cannot preserve all YAML mapping entries when keys repeat, cannot represent
complex mapping keys without a caller-owned key policy, and makes tag
normalization ambiguous. Merge keys are handled explicitly by the parser instead
of being hidden inside an arbitrary-value projection. The research constructor
also includes Foundation-specific scalar conversions, which would break the
dependency-free and WASM-compatible library boundary.

Application code may project `Model.Value` or `Tagged.Node` into JSON-like or
domain-specific values after validation. `Tagged.Constructor` is the supported
typed form of that projection, while dictionary-shaped `Any` projection remains
outside the library because it must own data-loss policy explicitly.

## Planned Compatibility Work

Compatibility should be added in small, test-backed slices:

1. Additional built-in validation rules beyond duplicate-key behavior.
2. Broader Codable compatibility beyond scalar, keyed, and unkeyed containers.
3. Yams corpus comparison tests in a separate compatibility suite.

The private `PureYAMLResearch` repository may be used to study Yams behavior, but
the public implementation must be written in Swift and must not copy C parser
source.

## Attribution Boundary

Yams and its bundled `CYaml` / libyaml-derived C parser are compatibility
references for PureYAML. They should guide test cases and behavior questions.
They are not source material to copy into this package.
