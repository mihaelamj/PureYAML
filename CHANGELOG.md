# Changelog

All notable changes to PureYAML are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Bootstrap PureYAML as a root Swift package with no external dependencies.
- Add the first pure-Swift YAML model, parser, and dumper milestone.
- Add tests for block mappings, block sequences, common scalars, comments, and
  dump/parse round trips.
- Add path-aware YAML validation with duplicate-key checks, custom rules, and
  warning collection.
- Add the internal parse event model with marks, scalar styles, collection
  styles, alias events, anchor/tag metadata, and golden event tests for current
  parser behavior.
- Add the internal UTF-8 reader and scanner token layer with tests for
  comments, indentation, block entries, mapping indicators, flow delimiters,
  quoted scalars, block scalar headers, anchors, aliases, tags, and source
  marks.
- Add the internal scanner-token event parser for block collections, flow
  collections, aliases, anchors, tags, and line/column parser failures.
- Add the internal event composer and wire public parsing through
  scanner-token events into `PureYAML.Model.Value`, including flow collections,
  block scalars, anchors, aliases, and duplicate-key validation coverage.
- Add YAML directive and document-marker scanning, tag-handle expansion, and
  explicit built-in scalar tag composition for strings, integers, floats,
  booleans, and nulls.
- Expand tests into focused parsing, dumping, model, validation, and parse-error
  suites.
- Add macOS, Linux, and WASM verification gates and CI jobs, plus a local Linux
  check that can run through Claw Mini's Lima VM.
- Add a single full local verification script and wire pre-push through the
  macOS, Claw Mini Linux, and WASM gate sequence.
- Harden the changelog gate so local verification also sees unstaged source
  edits, not only committed or staged changes.
- Add emitter options with a selectable scalar policy for quoted strings or
  conservative plain-string output.
- Add opt-in literal block scalar emission for safe multiline strings, including
  `|-` parsing support for stripped final newlines.
- Add opt-in flow collection emission for compact mapping and sequence output.
- Add emitter corpus tests and document the current emitter policy.
- Add Yams and CYaml attribution without copying their implementation into
  `Sources/`.
- Add validation-rule predicates, a boolean validation-rule initializer, and
  validator authoring rules.
- Add scalar typed Decodable and Encodable conversion APIs with exact
  path-aware errors.
- Add unambiguous bracket-quoted validation paths for punctuation-heavy keys.
- Add keyed typed Decodable and Encodable conversion for mapping-backed structs.
- Validate YAML values before typed decoding so duplicate keys are rejected
  deterministically.
- Add unkeyed typed Decodable and Encodable conversion for sequences, including
  nested sequences and sequence properties on keyed structs.
- Add a fixture-backed sequence typed-conversion test corpus and a
  forbidden-pattern verification gate for package, source, and test contracts.

### Changed

- Lower the package tools version to Swift 6.1 for hosted macOS CI compatibility
  and install Linux Swift toolchain prerequisites for the WASM CI job.
- Harden duplicate-key validation to use set membership while preserving exact
  diagnostics.
- Make validation rules immutable after construction.
