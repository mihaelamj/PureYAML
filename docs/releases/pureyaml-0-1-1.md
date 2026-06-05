# PureYAML 0.1.1

PureYAML 0.1.1 is a patch release that ships parser compatibility fixes and
stronger release verification gates.

## Highlights

- Treat more-indented plain scalar continuation lines that start with `-` as
  text unless they appear at a known sequence-entry indentation. This fixes
  OpenAPI-style `allOf` descriptions while preserving nested block sequences
  such as `- - 123`.
- Parse explicit scalar keys whose `:` value starts a same-line mapping and
  continues with indented mapping siblings, matching large OpenAPI schema keys.
- Add release-mode build and test gates to macOS, Linux, Windows, and WASM
  verification scripts.
- Add README platform CI badges and the production hardening roadmap.

## Current Production Readiness

PureYAML has Yams parse-success parity on the checked production corpus, but
that is not a proof of perfect YAML correctness. The active production
hardening work is tracked in #54, with child issues for structured validation
reports, diagnostic false-positive triage, malformed YAML coverage,
OpenAPIDoctor integration, Yams differential testing, and parser throughput.

## Verification

The release process requires:

- `bash scripts/check-all.sh`
- hosted macOS CI
- hosted Linux CI
- hosted Windows CI
- hosted WASM CI

## Installation

```swift
.package(url: "https://github.com/mihaelamj/PureYAML.git", .upToNextMinor(from: "0.1.1"))
```
