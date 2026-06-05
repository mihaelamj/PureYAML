# Changelog

All notable changes to PureYAML are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Nothing yet.

## [0.1.0] - 2026-06-05

### Added

- Bootstrap PureYAML as a root Swift package with one `PureYAML` library product,
  no external SwiftPM dependencies, no C sources, no generated parser targets,
  and no Foundation requirement in the library target.
- Add the core pure-Swift YAML model with ordered mappings, sequences, scalars,
  duplicate-key preservation, and first-class complex mapping keys through
  `Model.Pair.keyNode`.
- Add parser support for block mappings, block sequences, comments, flow
  collections, quoted strings, literal and folded block scalars, anchors,
  aliases, YAML directives, document markers, merge keys, complex mapping keys,
  multi-document streams, and selected explicit built-in scalar tags.
- Add deterministic YAML dumping with block output by default, optional flow
  collections, conservative plain scalars, conservative literal block scalars,
  complex mapping key dumping, and multi-document stream dumping.
- Add tag-preserving parsing with `PureYAML.parseTagged(_:)` and
  `PureYAML.parseTaggedStream(_:)`, plus tagged validation rules for unsupported
  built-in tags and tags applied to the wrong node kind.
- Add `PureYAML.Tagged.Constructor` for caller-owned tagged construction with
  exact missing-handler and kind-mismatch errors, recursive path context, and a
  model-value fallback that preserves mapping order and duplicate keys.
- Add path-aware validation with duplicate-key checks, custom rules, rule
  predicates, strict and non-strict behavior, warning collection, stream
  document indexes, deterministic validation paths, and direct value-tree
  validation for states ordinary loaders may collapse.
- Add diagnostic-first validation reports, raw-source preflight scanning,
  `Validation.ReportError`, and Markdown, YAML, and JSON report rendering for
  application-owned files or error bodies.
- Add scalar, keyed, unkeyed, nested, dynamic-key, dictionary-like, and
  super-coder `Codable` conversion APIs with exact path-aware errors.
- Add fixture-backed compatibility coverage for scalar spellings, explicit tags,
  collections, anchors, unsupported YAML gaps, literal block emission, downstream
  documents, and deliberately failing validation fixtures.
- Add a real-world YAML fixture corpus with representative short, medium, large,
  and very large documents, including OpenAPI, Kubernetes, GitHub Actions, Docker
  Compose, Prometheus, and cert-manager YAML.
- Add macOS, Linux, Windows, and WASM verification gates, hosted CI, a full
  local verification script, a pre-push hook, usage documentation, migration
  boundaries, attribution, and release notes.

### Changed

- Lower the package tools version to Swift 6.1 for hosted macOS CI compatibility.
- Harden duplicate-key validation to use set membership while preserving exact
  diagnostics.
- Make validation rules immutable after construction.
- Preserve keyed super-encoder field order even when delayed child encoders are
  written in a different order than they were requested.
- Make keyed default `superEncoder()` and `superDecoder()` use the standard
  `super` mapping key instead of the current mapping.
- Resolve Yams-compatible plain scalar spellings for `yes` and `no` booleans,
  radix-prefixed integers, numeric separators, and `.inf` and `.nan` floats.
- Broaden opt-in literal block emission while preserving exact parser
  round-trips for every emitted block scalar.
- Harden block mapping, multiline plain-scalar parsing, merge expansion, tagged
  parsing, lower-column mapping siblings, indented root fragments, JSON-style
  flow mapping pairs, tab-indented corpus files, and empty collection emission.
