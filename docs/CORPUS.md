# Corpus Gates

PureYAML's production hardening depends on real YAML first and generated cases
second. Synthetic generators are useful, but they must be anchored in documents
people actually maintain.

## Current State

The corpus gate is designed but not implemented yet. Implementation is tracked
by:

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

- at least 25 pinned public real-world YAML seeds,
- small enough for normal verification,
- runs on macOS and Linux by default,
- documents Windows and WASI depth if they run a smaller subset.

Full opt-in gate:

- at least 100 pinned public real-world YAML seeds,
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

Corpus runs should write artifacts under `.build/pureyaml-artifacts/`.

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

- The fast corpus has at least 25 pinned public real-world YAML seeds.
- The full corpus has at least 100 pinned public real-world YAML seeds.
- The manifest records provenance and expected outcomes for every seed.
- The mutation gate is derived from real seeds.
- Generated failures are reproducible by seed.
- Structured validation artifacts are produced even on failure.
- Differential disagreements against Yams are fixed or documented with reduced
  reproducers.
- New parser bugs are reduced into permanent fixtures or exact regression tests.
