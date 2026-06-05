# Research Compatibility Rules

PureYAML replaces behavior that is currently studied in the private
`PureYAMLResearch` repository. Compatibility work must be research-led and
implementation-independent.

## Mandatory Start Point

Before changing parser, scanner, composer, emitter, validation, or typed
Codable conversion behavior:

- inspect the matching source, tests, or fixtures in `PureYAMLResearch`;
- identify the observable behavior PureYAML should match or deliberately reject;
- write PureYAML tests that pin that behavior before or with the implementation;
- keep all public-package code original and dependency-free.

## Copying Boundary

Do not copy source from Yams, CYaml, libyaml, or research-only references into
`Sources/`. Use the research repository for behavior discovery only.

Allowed:

- exact behavioral assertions in PureYAML tests;
- attribution in `ATTRIBUTION.md` and design docs;
- small independently written fixtures that describe input and expected output.

Forbidden:

- copied parser, scanner, emitter, or encoder implementation code;
- C files, generated parser files, or external SwiftPM dependencies;
- compatibility claims that were not checked against the research source or a
  deliberate PureYAML design decision.

## Test Contract

Every compatibility test must pin at least one of:

- exact parsed value tree;
- exact emitted YAML;
- exact decoded Swift value;
- exact encoded value tree;
- exact validation issue;
- exact path-aware decoding or encoding error;
- exact required absence check for fields that must not appear.
