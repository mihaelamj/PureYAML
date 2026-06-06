# PureYAML 0.1.2

PureYAML 0.1.2 is a production-hardening release focused on real-world corpus
coverage, structured diagnostics, Yams comparison gates, JSON compatibility, and
lower-memory parser internals.

## Highlights

- Add a 114-seed real-world YAML corpus with opt-in full parse, validation, and
  round-trip checks.
- Add structured parser diagnostic codes and validation reports for malformed
  production-shaped YAML.
- Add JSON-subset compatibility tests against Swift's JSON decoder.
- Add Yams differential, diagnostic, validation, throughput, and phase-profiling
  artifact gates without adding Yams to the public package manifest.
- Route normal parsing through lazy token scanning and streamed event
  composition so `parse` and `parseStream` no longer retain a full token array or
  full intermediate event array.
- Improve ASCII-heavy scanner advancement with a UTF-8 reader cursor while
  preserving byte-accurate Unicode and CRLF source marks.

## Current Production Readiness

The checked corpus agrees with Yams on parse success and stream document counts.
PureYAML now has structured validation that reports duplicate keys with paths,
reasons, and severities, while Yams does not provide equivalent structured
validation output.

The public API still accepts complete `String` input. True chunked file/network
input streaming remains deferred to #43.

## Verification

The release candidate was locally verified with:

- `bash scripts/check-all.sh`
- `bash scripts/check-corpus.sh`
- `bash scripts/check-json-compatibility.sh`
- `bash scripts/check-yams-differential.sh`
- `bash scripts/check-yams-diagnostics.sh`
- `bash scripts/check-yams-validation.sh`
- `bash scripts/check-throughput.sh`
- `bash scripts/check-performance-phases.sh`

## Installation

```swift
.package(url: "https://github.com/mihaelamj/PureYAML.git", .upToNextMinor(from: "0.1.2"))
```
