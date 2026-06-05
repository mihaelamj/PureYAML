# PureYAML

[![Linux](https://img.shields.io/badge/Linux-CI-34C759?style=for-the-badge&logo=linux&logoColor=white&labelColor=1D1D1F)](https://github.com/mihaelamj/PureYAML/actions/workflows/ci.yml)

PureYAML is a dependency-free YAML package written entirely in Swift.

The goal is a Linux- and WebAssembly-compatible replacement for the YAML pieces
that currently force packages such as OpenAPIDoctor through C-backed parsers.
The package is intentionally strict about portability:

- no external SwiftPM dependencies
- no bundled C sources
- no Foundation requirement in the library target
- root Swift package layout
- macOS, Linux, and WASI build gates

## Roadmap

Mermaid status legend:

```mermaid
flowchart TB
  classDef done fill:#34C759,color:#000,stroke:#248A3D,stroke-width:2px
  classDef review fill:#FFCC00,color:#000,stroke:#B58B00,stroke-width:2px
  classDef active fill:#FF9500,color:#000,stroke:#B36200,stroke-width:2px
  classDef next fill:#007AFF,color:#fff,stroke:#005BBB,stroke-width:2px
  classDef partial fill:#AF52DE,color:#fff,stroke:#7D3CAF,stroke-width:2px
  classDef todo fill:#8E8E93,color:#fff,stroke:#6B6B70,stroke-width:2px
  LDone[Done]:::done
  LReview[Review]:::review
  LActive[Active]:::active
  LNext[Next]:::next
  LPartial[Partial]:::partial
  LTodo[Todo]:::todo
  LDone ~~~ LReview
  LReview ~~~ LActive
  LActive ~~~ LNext
  LNext ~~~ LPartial
  LPartial ~~~ LTodo
```

Epics overview:

```mermaid
flowchart TB
  classDef done fill:#34C759,color:#000,stroke:#248A3D,stroke-width:2px
  classDef review fill:#FFCC00,color:#000,stroke:#B58B00,stroke-width:2px
  classDef active fill:#FF9500,color:#000,stroke:#B36200,stroke-width:2px
  classDef next fill:#007AFF,color:#fff,stroke:#005BBB,stroke-width:2px
  classDef partial fill:#AF52DE,color:#fff,stroke:#7D3CAF,stroke-width:2px
  classDef todo fill:#8E8E93,color:#fff,stroke:#6B6B70,stroke-width:2px
  SuperEpic8["#8 Parser Replacement Roadmap - Active"]:::active
  Epic1["#1 Pure Swift Parse Core - Next"]:::next
  SuperEpic8 --> Epic1
```

Parse core detailed roadmap:

```mermaid
flowchart TB
  classDef done fill:#34C759,color:#000,stroke:#248A3D,stroke-width:2px
  classDef review fill:#FFCC00,color:#000,stroke:#B58B00,stroke-width:2px
  classDef active fill:#FF9500,color:#000,stroke:#B36200,stroke-width:2px
  classDef next fill:#007AFF,color:#fff,stroke:#005BBB,stroke-width:2px
  classDef partial fill:#AF52DE,color:#fff,stroke:#7D3CAF,stroke-width:2px
  classDef todo fill:#8E8E93,color:#fff,stroke:#6B6B70,stroke-width:2px
  Issue2["#2 Event Model and Golden Tests - Next"]:::next
  Issue3["#3 UTF-8 Reader and Scanner - Todo"]:::todo
  Issue4["#4 Token Stream to Events - Todo"]:::todo
  Issue5["#5 Events to PureYAML Values - Todo"]:::todo
  Issue6["#6 Scalars Tags and Aliases - Todo"]:::todo
  Issue7["#7 macOS Linux and WASM Hardening - Todo"]:::todo
  Issue2 --> Issue3
  Issue3 --> Issue4
  Issue4 --> Issue5
  Issue5 --> Issue6
  Issue6 --> Issue7
```

## Status

This repository starts with the first real parser milestone: block mappings,
block sequences, ordered mappings, common scalars, quoted strings, comments, and
a matching dumper. It also includes path-aware validation for structural YAML
checks such as duplicate mapping keys.

It is not yet a full YAML 1.2 implementation. Anchors, aliases, tags, flow
collections, folded scalars, literal scalars, directives, and custom decoding
are planned work.

## Attribution

PureYAML is informed by Yams and its bundled `CYaml` / libyaml-derived parser,
but it does not copy their implementation into `Sources/`. See
[ATTRIBUTION.md](ATTRIBUTION.md).

## Usage

```swift
import PureYAML

let document = try PureYAML.parse("""
openapi: 3.1.0
info:
  title: Example API
servers:
  - url: /
""")

let yaml = PureYAML.dump(document)

try PureYAML.validate(document)
```

## Development Contract

PureYAML must stay dependency-free and portable. Before merging changes:

```sh
bash scripts/check-style.sh
bash scripts/check-namespacing.sh
bash scripts/check-changelog-touched.sh
python3 scripts/check-roadmap.py
swiftformat . --config .swiftformat --lint
swiftlint --config .swiftlint.yml --strict
swift build
swift test
bash scripts/check-linux.sh
bash scripts/check-wasm.sh
```

`scripts/check-wasm.sh` expects a Swift toolchain with a matching Swift Wasm SDK.
For Swift 6.3.2, install the SDK with:

```sh
swift sdk install https://download.swift.org/swift-6.3.2-release/wasm-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_wasm.artifactbundle.tar.gz --checksum a61f0584c93283589f8b2f42db05c1f9a182b506c2957271402992655591dd7c
```

## License

MIT.
