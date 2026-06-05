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
│   ├── Event
│   ├── Mark
│   ├── Line
│   └── ParseError
├── Emitting
│   └── Dumper
└── Validation
    ├── Validator
    ├── Rule
    ├── Issue
    └── Path
```

`PureYAML.parse(_:)` and `PureYAML.dump(_:)` are convenience entry points. The
implementation lives in namespaced parser, dumper, and validator types.

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

The parser layer also has an internal event contract. `Parsing.Event` can
represent stream, document, scalar, sequence, mapping, and alias events, with
marks plus scalar and collection styles. Anchors and tags are carried as event
metadata so the later scanner/composer work can add YAML feature coverage
without changing the event shape.

The initial dumper emits block-style YAML from the model.

The initial validator traverses parsed YAML values and reports path-aware
issues. The default rule rejects duplicate mapping keys, and callers can build a
blank validator plus custom rules for project-specific checks.

## Planned Compatibility Work

Compatibility should be added in small, test-backed slices:

1. Flow collections.
2. Literal and folded scalars.
3. Anchors and aliases.
4. Tags.
5. Validation rules beyond duplicate-key behavior.
6. Codable-style decoding and encoding.
7. Yams corpus comparison tests in a separate compatibility suite.

The private `PureYAMLResearch` repository may be used to study Yams behavior, but
the public implementation must be written in Swift and must not copy C parser
source.

## Attribution Boundary

Yams and its bundled `CYaml` / libyaml-derived C parser are compatibility
references for PureYAML. They should guide test cases and behavior questions.
They are not source material to copy into this package.
