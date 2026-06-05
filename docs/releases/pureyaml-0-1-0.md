# PureYAML 0.1.0

PureYAML 0.1.0 is the first release of a dependency-free YAML package written
entirely in Swift.

## Highlights

- Root Swift package layout with one library product, `PureYAML`.
- No external SwiftPM dependencies.
- No C sources, generated parser targets, JavaScript tooling, or Foundation
  requirement in the library target.
- Pure Swift YAML model with ordered mappings, sequences, scalars, complex
  mapping keys, and duplicate-key preservation.
- Parser support for block mappings, block sequences, flow collections, quoted
  strings, comments, literal and folded block scalars, anchors, aliases, YAML
  directives, document markers, merge keys, complex mapping keys, multi-document
  streams, and selected explicit built-in scalar tags.
- Tag-preserving parsing and validation for callers that need explicit YAML tag
  metadata before project-owned construction.
- `PureYAML.Tagged.Constructor` for caller-owned tagged construction policies.
- Deterministic YAML dumper with block output by default, optional flow
  collections, conservative plain scalars, conservative literal block scalars,
  complex key dumping, and multi-document stream dumping.
- Path-aware validation with exact duplicate-key diagnostics, strict and
  non-strict modes, warning collection, custom rules, rule predicates, stream
  issue indexing, and direct value-tree validation for states ordinary loaders
  may collapse.
- Diagnostic-first validation reports for damaged YAML, including raw-source
  preflight diagnostics and `Validation.ReportError` for application-owned JSON
  or YAML error bodies.
- Typed `Codable` conversion for scalar, keyed, unkeyed, nested, dynamic-key,
  dictionary-like, and super-coder cases.
- Real-world fixture coverage, including OpenAPI, Kubernetes, GitHub Actions,
  Docker Compose, Prometheus, and cert-manager YAML.
- Local and hosted macOS, Linux, Windows, and WASM gates.

## Support Boundary

This is not a full YAML 1.2 implementation. The release intentionally ships a
tested subset with exact errors, validation reports, or fallback value trees for
known gaps.

Known deferred work is tracked in:

- #41: real YAML file fixture corpus expansion.
- #42: strict and compatibility parsing modes with validation reports.
- #43: streaming scanner/parser path for humongous YAML files.
- #44: humongous real-world YAML specs as a first-class validation gate.

## Verification

The 0.1.0 release process requires:

- `bash scripts/check-all.sh`
- hosted macOS CI
- hosted Linux CI
- hosted Windows CI
- hosted WASM CI

The full gate includes style, namespacing, forbidden-pattern, changelog,
roadmap, SwiftFormat, SwiftLint, host build, host tests, Linux build and test,
Windows build and test, and WASM build checks.

## Installation

```swift
.package(url: "https://github.com/mihaelamj/PureYAML.git", .upToNextMinor(from: "0.1.0"))
```
