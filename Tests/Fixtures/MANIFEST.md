# Real YAML Fixture Manifest

These fixtures are vendored test inputs. They are pinned to immutable GitHub
commit SHAs so compatibility failures can be reproduced without network access.
The files are not implementation source and are used only by
`RealYAMLFixtureTests`.

`real-yaml-corpus.yaml` is the machine-readable manifest for the full checked-in
corpus. It records every seed's stable ID, local path, category, tier, parser
expectations, byte count, line count, upstream repository, commit SHA, source
path, raw URL, and license note. Normal tests verify this manifest against the
vendored files. The full parse/validate/round-trip corpus gate is opt-in:

```sh
bash scripts/check-corpus.sh
```

| Local file | Size | Lines | Bytes | Upstream license | Pinned source |
|---|---:|---:|---:|---|---|
| `real-yaml/kubernetes-simple-pod.yaml` | very short | 12 | 186 | MIT | `ContainerSolutions/kubernetes-examples@fa6e84542f4350b97991bfffae553d248953e443/Pod/simple.yaml` |
| `real-yaml/kustomize-wordpress.yaml` | very short | 18 | 262 | Apache-2.0 | `kubernetes-sigs/kustomize@313aacedd3adcb6564fd362bcef52f5aa3abef85/examples/wordpress/kustomization.yaml` |
| `real-yaml/docker-compose-nginx-golang-postgres.yaml` | short | 48 | 852 | CC0-1.0 | `docker/awesome-compose@8ded149643ef0ba21fce5a5d39894b39fff6c7ee/nginx-golang-postgres/compose.yaml` |
| `real-yaml/github-actions-swift-format.yml` | short | 84 | 3591 | Apache-2.0 | `swiftlang/swift-format@fffd8df6153456838039aae4b9b901f6f31f5687/.github/workflows/pull_request.yml` |
| `real-yaml/openapi-petstore.yaml` | short | 119 | 2768 | Apache-2.0 | `OAI/OpenAPI-Specification@18c3204bc55c8c75fe25a039a3cf085f0e732208/_archive_/schemas/v3.0/pass/petstore.yaml` |
| `real-yaml/prow-cluster-api-presubmits.yaml` | medium | 427 | 14213 | Apache-2.0 | `kubernetes/test-infra@9001df901ba65b1b74d16be5cc910e68a5f35b91/config/jobs/kubernetes-sigs/cluster-api/cluster-api-release-1-13-presubmits.yaml` |
| `real-yaml/prometheus-conf-good.yml` | medium | 481 | 11562 | Apache-2.0 | `prometheus/prometheus@5e3c892bfc1209b739562f885a8cfa17c6cd7fa2/config/testdata/conf.good.yml` |
| `real-yaml/cert-manager-certificate-crd.yaml` | large | 883 | 44059 | Apache-2.0 | `cert-manager/cert-manager@59c5f5361a5b1cd2d0ca84cd9983a3beac3846bd/deploy/crds/cert-manager.io_certificates.yaml` |
| `real-yaml/cert-manager-values.yaml` | large | 1759 | 65536 | Apache-2.0 | `cert-manager/cert-manager@59c5f5361a5b1cd2d0ca84cd9983a3beac3846bd/deploy/charts/cert-manager/values.yaml` |
| `real-yaml/github-rest-api.yaml` | extreme | 257280 | 9549118 | MIT | `github/rest-api-description@0d4e436c347b444cd71b4eb1bd73948fd51c3402/descriptions-next/api.github.com/api.github.com.yaml` |

Selection covers GitHub Actions, Docker Compose, Kubernetes manifests,
Kustomize, OpenAPI, Prow jobs, Prometheus config, Helm values, CRDs, and one
extreme OpenAPI document. If a fixture is parseable by mature YAML tools, this
suite expects PureYAML to parse it or to pin an exact unsupported feature error
with a linked issue.

Additional opt-in full-corpus seeds are listed in `real-yaml-corpus.yaml` and
stored beside the default fixtures under `real-yaml/`. The opt-in set includes
large public APIs.guru Stripe and Zoom OpenAPI YAML specs.

## ACME Fixtures

`acme/` contains synthetic OpenAPI fixtures modeled after downstream
Stitcher-style and multi-module catalog inputs. `acme/birch-catalog/` preserves
the original module/file structure of a private Birch-shaped catalog while
renaming private organization names, domains, and documentation URLs.

| Local file | Purpose |
|---|---|
| `acme/zephyr-data/spec.yml` | Multi-file OpenAPI root with relative `$ref` component references. |
| `acme/zephyr-data/schemas/activeZorplexFeature.yml` | Referenced object schema with nested properties and nullable fields. |
| `acme/zephyr-data/schemas/zorplexFeature.yml` | Referenced enum schema. |
| `acme/zephyr-data/bundled.yml` | Bundled output shape after external references are resolved. |
| `acme/birch-catalog/**/*.yml` | Full renamed Birch-style catalog with 594 YAML files, quoted OAuth scope keys, request bodies, shared parameters, and cross-module refs. |

## Validation Failure Fixtures

These fixtures are intentionally valid YAML that should fail validation. They
exist to demonstrate exact validation output for user-facing diagnostic reports,
strict throwing behavior, non-strict warning returns, path rendering, required
presence checks, and required absence checks.

| Local file | Purpose |
|---|---|
| `validation-failures/duplicate-keys.yaml` | Default duplicate-key diagnostics with root and punctuation-heavy nested keys. |
| `validation-failures/missing-required-and-forbidden.yaml` | Custom required-presence plus required-absence diagnostics in one document. |
| `validation-failures/warnings.yaml` | Warning-only diagnostics that throw in strict mode and return in non-strict mode. |
