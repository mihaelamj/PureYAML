# Release Process

PureYAML versioning is driven by Git tags. The current release target is 0.1.0.
Do not publish the tag until #32 records final local and hosted verification.

## 0.1.0 Candidate

- Swift tools version: 6.1
- Product: `PureYAML`
- SwiftPM dependencies: none
- Source targets: Swift only, no C targets and no generated parser targets
- Hosted CI matrix: macOS build and test, Linux build and test, WASM build
- Release notes file: `docs/releases/pureyaml-0-1-0.md`

## Local Verification

Run the full gate from a clean checkout before tagging:

```sh
git status --short --branch
bash scripts/check-all.sh
```

`scripts/check-all.sh` expands to:

```sh
bash scripts/check-style.sh
bash scripts/check-namespacing.sh
bash scripts/check-forbidden-patterns.sh
bash scripts/check-changelog-touched.sh
bash scripts/check-roadmap.sh
swiftformat . --config .swiftformat --lint
swiftlint --config .swiftlint.yml --strict
swift build
swift test
bash scripts/check-linux.sh
bash scripts/check-wasm.sh
```

The Linux check must exercise build and tests. The WASM check must build the
library target with the configured Swift Wasm SDK.

## Hosted Verification

Push `main` and wait for the CI workflow to pass:

```sh
git push origin main
gh run list --repo mihaelamj/PureYAML --branch main --limit 5
gh run watch <run-id> --repo mihaelamj/PureYAML --exit-status
```

The passing run must include all CI jobs:

- macOS
- Linux
- WASM

## Tag and Publish

Only run these commands after the local gates pass, hosted CI passes, and #32 is
updated with the final evidence.

```sh
git status --short --branch
git tag -a 0.1.0 -m "PureYAML 0.1.0"
git push origin main 0.1.0
gh release create 0.1.0 \
  --repo mihaelamj/PureYAML \
  --title "PureYAML 0.1.0" \
  --notes-file docs/releases/pureyaml-0-1-0.md
```

After publishing, verify the release exists:

```sh
git ls-remote --tags origin 0.1.0
gh release view 0.1.0 --repo mihaelamj/PureYAML
```

## Do Not Tag If

- `Package.swift` has any external dependency.
- `Sources/` contains C, JavaScript, WebAssembly blobs, or generated parser
  runtime files.
- Any Swift source imports Foundation in the library target.
- The changelog does not have a dated 0.1.0 section.
- The release notes omit the known deferred issues.
- macOS, Linux, or WASM CI is red or still running.
