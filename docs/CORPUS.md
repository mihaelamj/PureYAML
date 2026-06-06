# Corpus Gates

PureYAML's production hardening depends on real YAML first and generated cases
second. Synthetic generators are useful, but they must be anchored in documents
people actually maintain.

## Current State

The checked-in corpus gate is implemented. `Tests/Fixtures/real-yaml-corpus.yaml`
is the machine-readable manifest for 114 pinned public YAML seeds copied under
`Tests/Fixtures/real-yaml/`.

Normal `swift test` verifies the manifest and vendored file metadata without
running the full corpus parse workload. It also runs deterministic generated
properties over small valid YAML documents and malformed mutations derived from
default real-corpus seeds. Run the full checked-in corpus gate explicitly when
hardening parser behavior:

```sh
bash scripts/check-corpus.sh
```

The opt-in gate sets `PUREYAML_RUN_FULL_CORPUS=1` and runs
`RealYAMLCorpusTests`. It stream-parses every seed, validates every document,
and checks parse/dump/parse stability for seeds marked as round-trippable in the
manifest. A successful run writes corpus artifacts under
`.build/pureyaml-artifacts/`.

The normal `parse` and `parseStream` paths now scan tokens lazily and compose
values from parser events as those events are produced. They no longer retain a
full token array or a full intermediate event array. `parseEvents` remains
available as a debugging and compatibility surface that materializes events
explicitly. This is an internal memory-reduction step; the public API still
accepts a complete `String`, so true chunked input parsing remains tracked by
#43.

`RealYAMLCorpusPropertyTests` runs in normal verification and covers:

- 100 deterministic generated valid YAML documents with parse/dump/parse
  stability;
- malformed real-seed mutations for missing mapping spaces, tab indentation,
  broken sequence markers, broken quoted scalars, and undefined aliases;
- structured diagnostics for every generated malformed mutation.

Run the JSON compatibility gate to prove YAML 1.2 JSON-subset behavior against
Swift's JSON decoder:

```sh
bash scripts/check-json-compatibility.sh
```

The gate covers object, array, and scalar roots; JSON escapes; Unicode escape
sequences including surrogate pairs; exponent numbers; nested values; and
insignificant whitespace. It writes
`.build/pureyaml-artifacts/json/json-compatibility.json`.

Run the Yams comparison gate separately because it intentionally uses an
external dependency in a temporary package under `.build/`:

```sh
bash scripts/check-yams-differential.sh
```

This preserves `Package.swift`'s dependency-free contract while producing
`.build/pureyaml-artifacts/differential/yams-comparison.json`.

The manifest can mark intentional differences. The current checked-in corpus has
one: a comment-only values file where PureYAML returns a single `null` document
and Yams reports zero stream documents. The differential gate accepts only
manifest-declared intentional differences.

Malformed-input diagnostics are compared separately:

```sh
bash scripts/check-yams-diagnostics.sh
```

This gate checks production-shaped bad YAML cases where PureYAML emits
machine-readable diagnostic codes, locations, severities, and descriptions, then
records the corresponding Yams parser result in
`.build/pureyaml-artifacts/diagnostics/yams-diagnostics.json`.

Parsed-document validation is compared separately:

```sh
bash scripts/check-yams-validation.sh
```

This gate checks YAML that both parsers can load but that contains semantic
validation issues such as duplicate mapping keys. PureYAML reports structured
validation paths and reasons; the artifact records Yams' parser result and zero
structured validation issues at
`.build/pureyaml-artifacts/validation/yams-validation.json`.

Throughput comparison is also opt-in and uses the same temporary-package
pattern:

```sh
bash scripts/check-throughput.sh
```

It measures representative checked-in corpus seeds against Yams in release mode
and writes `.build/pureyaml-artifacts/performance/yams-throughput.json`.

PureYAML phase profiling is a separate release-mode gate:

```sh
bash scripts/check-performance-phases.sh
```

It times scanner, token-to-event parsing, event composition, lazy full parsing,
validation, and dumping for the slow representative seeds. It writes
`.build/pureyaml-artifacts/performance/phase-profile.json` so parser
optimization work can target the dominant phase instead of guessing from total
Yams comparison time. The scanner now keeps a UTF-8 cursor for byte-accurate
source marks, which avoids per-character string allocation in ASCII-heavy
advancement while preserving Unicode and CRLF behavior.

Round-trip expectations are tracked separately. A seed can remain in the parse,
validation, and differential gates while skipping parse/dump/parse equality when
the dumper does not yet preserve that document shape.

Further implementation is tracked by:

- #54, the production hardening epic.
- #55, the real-world seed, fuzz, and property-based validation gate.
- #53, Yams differential testing.
- #51, mutation-based bad-YAML validation fixtures.
- #44, humongous real-world YAML specs.

## Goal

Build deterministic parser and validation gates that combine:

- pinned real-world YAML seeds,
- original-file parser and validator checks,
- deterministic valid and invalid mutations from those seeds,
- property checks for parser and dumper stability,
- differential comparison against Yams where the input is inside the shared
  supported subset,
- structured artifacts that explain every failure.

Every discovered bug must become a reduced fixture or exact regression test.
Artifacts are useful for triage, but committed tests are the permanent truth.

## Seed Sources

The first corpus should be built from public repositories with pinned commits.

| Source | Seed Type | Example Paths |
|---|---|---|
| `github/rest-api-description` | Large OpenAPI 3.0 and 3.1 specs | `descriptions-next/api.github.com/api.github.com.yaml`, `descriptions-next/api.github.com/dereferenced/api.github.com.deref.yaml`, `descriptions-next/ghec/ghec.yaml` |
| `APIs-guru/openapi-directory` | Broad OpenAPI and Swagger corpus | `APIs/1password.com/events/1.2.0/openapi.yaml`, `APIs/ably.io/platform/1.1.0/openapi.yaml`, `APIs/adyen.com/CheckoutService/70/openapi.yaml`, `APIs/adafruit.com/2.0.0/swagger.yaml` |
| `OAI/OpenAPI-Specification` | Canonical OpenAPI examples | `_archive_/schemas/v3.0/pass/petstore.yaml`, `_archive_/schemas/v3.0/pass/petstore-expanded.yaml`, `_archive_/schemas/v3.0/pass/uspto.yaml`, `_archive_/schemas/v3.0/schema.yaml` |
| `argoproj/argo-cd` | Kubernetes, GitOps, ApplicationSet, Helm | `applicationset/examples/design-doc/applicationset.yaml`, `applicationset/examples/git-generator-directory/cluster-addons/prometheus-operator/values.yaml` |
| `prometheus/prometheus` | Good and intentionally bad app config | `config/testdata/conf.good.yml`, `cmd/promtool/testdata/prometheus-config.good.yml`, `cmd/promtool/testdata/prometheus-config.bad.yml`, `cmd/promtool/testdata/rules_large.yml` |
| `bitnami/charts` | Helm and Kubernetes chart YAML | `bitnami/airflow/values.yaml`, `bitnami/apache/Chart.yaml`, `bitnami/airflow/templates/web/deployment.yaml` |

The corpus should include API and non-API YAML:

- OpenAPI 3.0, OpenAPI 3.1, and Swagger 2.0.
- Kubernetes manifests.
- Helm chart metadata, values files, and templates that are valid YAML.
- GitHub Actions workflows.
- Docker Compose files.
- Prometheus configs and rule files.
- Static-site, package, and application settings.
- Intentionally bad real fixtures from upstream projects when available.

## Manifest

Every seed must be listed in a manifest. The manifest should include:

- stable seed ID,
- repository owner and name,
- commit SHA or release tag,
- source path,
- raw URL,
- category,
- byte size,
- line count,
- license or provenance note,
- expected parser outcome,
- expected validation outcome,
- whether the seed belongs in the fast/default corpus,
- whether the seed belongs only in the full opt-in corpus.

Huge files or files with awkward licensing should be downloaded by a corpus
script rather than committed directly. Reduced fixtures that capture bugs should
be committed in `Tests/Fixtures/`.

## Corpus Sizes

Fast/default gate:

- 114 pinned public real-world YAML seeds copied into `Tests/Fixtures/real-yaml/`,
- normal verification checks the manifest and file metadata only,
- runs on macOS and Linux by default,
- documents Windows and WASI depth if they run a smaller subset.

Full opt-in gate:

- first opt-in gate covers the 114 checked-in seeds with parse, validation, and
  round-trip properties,
- default generated properties cover valid document stability and malformed
  real-seed mutation diagnostics,
- Yams differential gate compares parse success and stream document counts for
  the checked-in corpus,
- target is met with at least 100 pinned public real-world YAML seeds,
- includes at least 20 very large OpenAPI files,
- includes at least 20 non-API config files,
- includes valid and intentionally invalid upstream fixtures where available.

## Mutation Coverage

Mutations should start from real seeds and cover common production mistakes:

- spacing after mapping colons,
- indentation drift,
- broken sequence markers,
- tab indentation in sensitive positions,
- malformed anchors and aliases,
- unknown aliases,
- broken quoted scalars,
- broken literal and folded block scalars,
- flow sequence and flow mapping mistakes,
- duplicate mapping keys,
- explicit key and explicit value mistakes,
- stream boundary mistakes.

Generated malformed input must assert structured validation/report behavior, not
only that parsing throws.

## Properties

The generated gate should include deterministic properties such as:

- successful parse and dump and parse stability where PureYAML owns both parse
  and dump semantics,
- no crash on malformed input,
- parser failures produce structured diagnostics when requested,
- Yams differential agreement for inputs inside the shared supported subset,
- every failure records the real seed ID and generator seed.

Every generated failure must be reproducible from a seed. Any non-trivial
failure should be reduced into a stable checked-in regression fixture.

## Artifacts

Corpus runs write artifacts under `.build/pureyaml-artifacts/`.

```text
.build/pureyaml-artifacts/
  real-seed-manifest.json
  real-seed-summary.yaml
  generated-validation-summary.json
  generated-validation-summary.yaml
  seeds.json
  failures/
    seed-id-000123.input.yaml
    seed-id-000123.mutated.yaml
    seed-id-000123.diagnostics.json
    seed-id-000123.reduced.yaml
  differential/
    yams-comparison.json
  environment.txt
```

CI should upload these artifacts with the current Node 24-compatible artifact
action:

```yaml
- name: Upload corpus artifacts
  if: always()
  uses: actions/upload-artifact@v6
  with:
    name: pureyaml-corpus-${{ runner.os }}-${{ github.sha }}
    path: .build/pureyaml-artifacts
    retention-days: 30
```

Artifacts are temporary. Issues and commits must link the relevant artifact
while it exists, then preserve the important case as a committed fixture.

## Acceptance Checklist

- The checked-in corpus has at least 25 pinned public real-world YAML seeds.
- The full corpus has at least 100 pinned public real-world YAML seeds.
- The manifest records provenance and expected outcomes for every seed.
- The mutation gate is derived from real seeds.
- Generated failures are reproducible by seed.
- Structured validation artifacts are produced even on failure.
- Differential disagreements against Yams are fixed or documented with reduced
  reproducers.
- New parser bugs are reduced into permanent fixtures or exact regression tests.
