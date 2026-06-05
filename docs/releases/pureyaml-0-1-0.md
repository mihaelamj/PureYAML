# PureYAML 0.1.0

PureYAML 0.1.0 is the first release of a dependency-free YAML package written
entirely in Swift.

## Highlights

- Root Swift package layout with one library product, `PureYAML`.
- No external SwiftPM dependencies.
- No C sources, generated parser targets, JavaScript tooling, or Foundation
  requirement in the library target.
- Pure Swift YAML model with ordered mappings, sequences, scalars, and duplicate
  key preservation.
- Parser support for block mappings, block sequences, flow collections, quoted
  strings, comments, literal and folded block scalars, anchors, aliases, YAML
  directives, document markers, and selected explicit built-in scalar tags.
- Deterministic YAML dumper with block output by default, optional flow
  collections, conservative plain scalars, and conservative literal block
  scalars.
- Path-aware validation with exact duplicate-key diagnostics, strict and
  non-strict modes, warning collection, custom rules, rule predicates, and
  direct value-tree validation for states ordinary loaders may collapse.
- Typed `Codable` conversion for scalar, keyed, unkeyed, nested, dynamic-key,
  dictionary-like, and super-coder cases.
- Compatibility and downstream-shaped fixture coverage, including explicit
  unsupported-gap tests.
- Local and hosted macOS, Linux, and WASM gates.

## Support Boundary

This is not a full YAML 1.2 implementation. The release intentionally ships a
tested subset with exact errors or exact fallback value trees for known gaps.

Known deferred work is tracked in:

- #33: multi-document YAML streams
- #34: merge keys and complex mapping keys
- #35: tag-specific YAML types
- #36: fixture-backed validator corpus expansion
- #37: arbitrary `Any` load and dump API decision

## Verification

The 0.1.0 release process requires #32 to record:

- `bash scripts/check-all.sh`
- hosted macOS CI
- hosted Linux CI
- hosted WASM CI

The full gate includes style, namespacing, forbidden-pattern, changelog,
roadmap, SwiftFormat, SwiftLint, host build, host tests, Linux build and test,
and WASM build checks.

## Installation After Tagging

```swift
.package(url: "https://github.com/mihaelamj/PureYAML.git", .upToNextMinor(from: "0.1.0"))
```
