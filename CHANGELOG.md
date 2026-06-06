# Changelog

All notable changes to PureYAML are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.2] - 2026-06-06

### Added

- Document the real-world YAML corpus, fuzz/property gate, and CI artifact
  contract for production hardening.
- Add machine-readable parser diagnostic codes to validation report payloads and
  cover malformed production-shaped YAML with 10+ structured diagnostics.
- Vendor a 114-file real-world YAML corpus with a machine-readable manifest,
  default metadata checks, and an opt-in full parse/validate/round-trip gate.
- Add large public APIs.guru Stripe and Zoom OpenAPI YAML specs to the opt-in
  corpus gate.
- Add a reduced synthetic ACME Zephyr fixture set for Stitcher-style multi-file
  OpenAPI inputs and bundled output.
- Add a full renamed Birch-style ACME fixture catalog with 594 YAML files,
  preserving module/file structure while replacing private organization names,
  domains, and documentation URLs.
- Add YAML 1.2 JSON-subset compatibility for compact flow mappings such as
  `{"openapi":"3.0.0"}`, including regression coverage for colons inside flow
  mapping values.
- Add JSON compatibility tests and artifacts that compare PureYAML against
  Swift's JSON decoder across JSON roots, escapes, Unicode surrogate pairs,
  exponent numbers, nested values, and whitespace.
- Preserve round-trip fidelity for mapping keys that require quotes, including
  trailing-space keys found in the large Zoom OpenAPI corpus seed.
- Add an opt-in Yams differential script that compares parse behavior for the
  checked-in real corpus without adding Yams to the PureYAML package manifest.
- Add an opt-in Yams diagnostic comparison script that records PureYAML
  structured malformed-input diagnostics alongside Yams parser errors.
- Add an opt-in Yams validation comparison script proving structured duplicate
  key validation on YAML that both parsers can load.
- Add an opt-in Yams throughput script and scheduled/manual CI artifact for
  release-mode parser performance comparison on representative corpus seeds.
- Add an opt-in PureYAML phase profiler that times scanner, event parser,
  composer, lazy parse, validation, and dumping phases on slow corpus seeds.
- Compose normal parser output from events as they are emitted, avoiding a full
  intermediate event array while keeping `parseEvents` available for explicit
  event materialization.
- Lazily scan tokens for normal `parse` and `parseStream` calls, avoiding a
  retained full token array on the main parser path.
- Track reader positions with a UTF-8 cursor so ASCII-heavy scanner advancement
  avoids per-character string allocation while preserving byte-accurate marks.
- Add deterministic generated corpus properties for valid YAML round trips and
  malformed real-seed mutations with structured diagnostics.
- Write corpus run artifacts under `.build/pureyaml-artifacts/`, including real
  seed summaries, generated mutation summaries, seed metadata, and environment
  details.
- Add a scheduled/manual CI corpus job that runs the corpus and Yams
  differential gates and uploads the generated artifact bundle.

## [0.1.1] - 2026-06-06

### Added

- Add platform CI badges and an active production-hardening roadmap to the
  README.

### Changed

- Add release-mode build and test gates to the macOS, Linux, Windows, and WASM
  verification scripts.
- Update GitHub Actions checkout steps to `actions/checkout@v6` so CI uses the
  current Node 24 action runtime.

### Fixed

- Treat more-indented plain scalar continuation lines that start with `-` as
  text unless they appear at a known sequence-entry indentation. This fixes
  OpenAPI-style `allOf` descriptions while preserving nested block sequences
  such as `- - 123`.
- Parse explicit scalar keys whose `:` value starts a same-line mapping and
  continues with indented mapping siblings, matching large OpenAPI schema keys.

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
