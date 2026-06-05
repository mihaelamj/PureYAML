# PureYAML

[![Linux](https://img.shields.io/github/actions/workflow/status/mihaelamj/PureYAML/ci.yml?branch=main&label=Linux&logo=linux)](https://github.com/mihaelamj/PureYAML/actions/workflows/ci.yml)

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

The roadmap uses the TileDown Mermaid palette: green for merged work, yellow for
review, purple for epic grouping, and gray for open work with no PR.

```mermaid
flowchart TB
  classDef done fill:#ddf9e4,stroke:#34c759,color:#111827
  classDef review fill:#fff7d6,stroke:#ffcc00,color:#111827
  classDef epic fill:#f2e5ff,stroke:#af52de,color:#111827
  classDef todo fill:#f2f4f7,stroke:#8e8e93,color:#111827
  LDone["In main now"]:::done
  LReview["PR in review"]:::review
  LEpic["Epic grouping"]:::epic
  LTodo["Open issue, no PR"]:::todo
  LDone ~~~ LReview
  LReview ~~~ LEpic
  LEpic ~~~ LTodo
```

Epics overview:

```mermaid
flowchart TB
  classDef done fill:#ddf9e4,stroke:#34c759,color:#111827
  classDef review fill:#fff7d6,stroke:#ffcc00,color:#111827
  classDef epic fill:#f2e5ff,stroke:#af52de,color:#111827
  classDef todo fill:#f2f4f7,stroke:#8e8e93,color:#111827
  SuperEpic8["#8 Parser Replacement Roadmap"]:::epic
  Epic1["#1 Pure Swift Parse Core"]:::epic
  SuperEpic8 --> Epic1
```

Parse core detailed roadmap:

```mermaid
flowchart TB
  classDef done fill:#ddf9e4,stroke:#34c759,color:#111827
  classDef review fill:#fff7d6,stroke:#ffcc00,color:#111827
  classDef epic fill:#f2e5ff,stroke:#af52de,color:#111827
  classDef todo fill:#f2f4f7,stroke:#8e8e93,color:#111827
  Issue2["#2 Event Model and Golden Tests"]:::done
  Issue3["#3 UTF-8 Reader and Scanner"]:::done
  Issue4["#4 Token Stream to Events"]:::todo
  Issue5["#5 Events to PureYAML Values"]:::todo
  Issue6["#6 Scalars Tags and Aliases"]:::todo
  Issue7["#7 macOS Linux and WASM Hardening"]:::todo
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
bash scripts/check-roadmap.sh
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
