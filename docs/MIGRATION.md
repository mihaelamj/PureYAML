# Migration and YAML Support Boundaries

PureYAML can replace a C-backed YAML parser when the caller needs dependency-free
Swift parsing, emitting, validation, and typed conversion for the currently
tested YAML subset.

It should not be treated as a drop-in full YAML implementation yet. The current
contract is the behavior pinned by the Swift Testing corpus.

## Attribution Boundary

PureYAML is informed by the behavior and public API shape of Yams and its bundled
`CYaml` / libyaml-derived parser. The public implementation is original Swift
code in this repository. Do not copy Yams, CYaml, or libyaml implementation code
into `Sources/`.

See [../ATTRIBUTION.md](../ATTRIBUTION.md) for the project attribution.

## Migration Map

| Existing need | PureYAML path | Notes |
|---|---|---|
| Compose YAML into a native YAML tree | `PureYAML.parse(_:)` | Returns `PureYAML.Model.Value`, preserving mapping order and duplicate keys. |
| Serialize a YAML tree | `PureYAML.dump(_:options:)` | Emits deterministic YAML with explicit block, flow, and scalar policies. |
| Decode a `Decodable` type from YAML | `PureYAML.decode(_:from:)` | Runs default validation before typed decoding. |
| Encode an `Encodable` value to YAML | `PureYAML.encodeToYAML(_:options:)` | Encodes through `PureYAML.Model.Value`, then dumps. |
| Validate document structure | `PureYAML.validate(_:using:strict:)` | Default rule reports duplicate mapping keys with exact paths. |
| Load arbitrary `Any` dictionaries and arrays | Use `Model.Value` or typed `Codable` | There is deliberately no public arbitrary `Any` conversion API. Dictionary-shaped values erase YAML diagnostics. |

## Arbitrary Any Decision

PureYAML does not expose `loadAny`, `dumpAny`, or dictionary-and-array `Any`
entry points. That is a deliberate compatibility boundary, not a missing
wrapper.

The research implementation's arbitrary-value constructor is useful to study,
but its observable shape conflicts with PureYAML's first principles:

- mapping conversion becomes dictionary-shaped, so duplicate keys and insertion
  order are not a first-class contract;
- merge keys may be flattened during construction instead of remaining visible
  to validation;
- scalar construction includes Foundation-specific values such as binary data,
  dates, and null objects;
- custom constructors can hide whether a document was parsed, normalized,
  flattened, or validated.

For unknown schemas, use `PureYAML.Model.Value` and validate before projecting
into project-specific values. For known schemas, use typed `Codable`. If a
caller truly needs a JSON-like dictionary after validation, build that projection
in the application layer where duplicate-key and unsupported-shape policies are
explicit.

## Supported Today

The supported list below is covered by tests. When adding a new migration case,
add a fixture beside the closest existing suite.

| Area | Current behavior | Test coverage |
|---|---|---|
| Block mappings and sequences | Parsed into ordered mappings and sequences. | `ParsingTests`, `CollectionCompatibilityFixtures` |
| Common scalars | Null, booleans, integers, doubles, and strings resolve into model values. | `ParsingTests`, `ScalarCompatibilityFixtures` |
| Quoted strings | Single and double quoted strings keep string intent. | `ParsingTests`, `ScalarCompatibilityFixtures` |
| Comments | Comments outside quoted strings are ignored. Hash characters inside quoted strings remain content. | `ParsingTests` |
| Flow collections | Flow sequences and flow mappings compose into model values. | `ParsingTests`, `CollectionCompatibilityFixtures` |
| Literal and folded blocks | Block scalar text is preserved according to current parser rules. | `ParsingTests`, `DumperTests` |
| Anchors and aliases | Scalar and mapping anchors can be reused through aliases. Undefined aliases throw exact parse errors. | `ParsingTests`, `CollectionCompatibilityFixtures` |
| YAML directives and document markers | `%YAML 1.2`, selected `%TAG` expansion, `---`, and `...` are supported for single-document streams. | `ParsingCompatibilityTests` |
| Built-in scalar tags | `!!str`, `!!int`, `!!float`, `!!bool`, and `!!null` are applied when valid. | `ScalarCompatibilityFixtures` |
| Emitting | Deterministic block output by default, with opt-in flow collections and conservative literal blocks. | `DumperTests`, `EmitterCorpusTests` |
| Typed conversion | Scalar, keyed, unkeyed, nested, sequence, dynamic-key, and super-coder cases are covered. | `CodingTests`, `CodableCompatibilityTests` |
| Validation | Duplicate mapping keys are reported with exact issue paths. | `ValidationTests`, `ValidationModelTests` |
| Downstream-shaped documents | API-style and service-configuration documents parse and decode through representative paths. | `DownstreamDocumentTests` |

## Current Unsupported Behavior

Unsupported behavior is either rejected with an exact error or preserved as an
explicit fallback value tree. This avoids silent compatibility drift.

| YAML pattern | Current PureYAML behavior | Test coverage |
|---|---|---|
| Multi-document streams | Throws `unsupportedMultiDocumentStream`. | `UnsupportedYAMLGapsFixtures.parseErrors` |
| Content after explicit document end | Throws `unsupportedMultiDocumentStream`; trailing comments after `...` remain non-content. | `UnsupportedYAMLGapsFixtures` |
| Complex mapping keys such as `? [a, b]` or `? {name: Example}` | Throws `expectedScalarKey`. | `UnsupportedYAMLGapsFixtures.parseErrors` |
| Unknown directives such as `%FOO` | Throws `unsupportedDirective`. | `UnsupportedYAMLGapsFixtures.parseErrors` |
| `%TAG` after content or after document start | Throws `unsupportedDirective`. | `UnsupportedYAMLGapsFixtures.parseErrors` |
| Undefined aliases | Throws `undefinedAlias`. | `CollectionCompatibilityFixtures.parseErrors` |
| Invalid explicit scalar tag values | Throws `invalidTaggedScalar`. | `ScalarCompatibilityFixtures.invalidExplicitScalarTags` |
| Merge keys | Keeps `<<` as an ordinary mapping entry; it does not flatten merged keys. | `UnsupportedYAMLGapsFixtures.fallbackValues`, `DownstreamDocumentTests` |
| Unsupported built-in tags such as `!!timestamp`, `!!binary`, `!!set`, and `!!omap` | Keeps parseable value trees without special tag semantics. | `UnsupportedYAMLGapsFixtures.fallbackValues` |
| Sexagesimal-style scalars and date-looking plain scalars | Keep string values for currently unsupported spellings such as `1:20`, `2002-04-28`, and `09`. | `ScalarCompatibilityFixtures.unsupportedScalars` |
| Custom constructors, custom resolvers, and environment expansion | Not implemented. Build project-specific conversion on top of `Model.Value` or typed `Codable`. | Planned future work |
| Foundation-specific scalar conversions such as `Data`, `Date`, or `URL` strategies | Not special-cased in the library target. Encode explicit strings or typed models instead. | Planned future work |

## Migration Checklist

1. Audit the YAML corpus the caller actually reads and writes.
2. Classify each document against the supported and unsupported tables above.
3. Add representative fixtures for project-specific documents before switching
   call sites.
4. Parse through `PureYAML.parse(_:)` and run `PureYAML.validate(_:)` before
   typed decoding when duplicate-key visibility matters.
5. Prefer typed `Codable` for known schemas and `PureYAML.Model.Value` for
   inspection, migration tooling, or unsupported-shape triage.
6. Run macOS, Linux, and WASM gates before publishing the migration.

## When Not to Migrate Yet

Do not migrate a caller yet if it requires:

- multi-document stream loading or dumping;
- YAML merge-key flattening;
- complex mapping keys as first-class keys;
- binary or timestamp conversion into Foundation types;
- arbitrary `Any` load and dump APIs;
- custom scalar constructors or resolvers;
- a full YAML 1.2 compliance claim.

In those cases, add a fixture and a child issue before changing production call
sites.
