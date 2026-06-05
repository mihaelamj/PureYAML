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
- Expand tests into focused parsing, dumping, model, validation, and parse-error
  suites.
- Add macOS, Linux, and WASM verification gates and CI jobs, plus a local Linux
  check that can run through Claw Mini's Lima VM.
- Add Yams and CYaml attribution without copying their implementation into
  `Sources/`.
