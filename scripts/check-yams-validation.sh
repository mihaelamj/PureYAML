#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.build/yams-validation"
ARTIFACT_DIR="$ROOT_DIR/.build/pureyaml-artifacts/validation"

mkdir -p "$WORK_DIR/Sources/YamsValidation" "$ARTIFACT_DIR"

cat > "$WORK_DIR/Package.swift" <<EOF
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PureYAMLYamsValidation",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "$ROOT_DIR"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "YamsValidation",
            dependencies: [
                "PureYAML",
                .product(name: "Yams", package: "Yams"),
            ],
        ),
    ],
)
EOF

cat > "$WORK_DIR/Sources/YamsValidation/main.swift" <<'EOF'
import Foundation
import PureYAML
import Yams

struct Case {
    var id: String
    var yaml: String
    var expectedIssueCount: Int
}

struct Comparison {
    var testCase: Case
    var pureParseSuccess: Bool
    var pureIssues: [PureYAML.Validation.Issue]
    var pureError: String?
    var yamsParseSuccess: Bool
    var yamsDocumentCount: Int?
    var yamsError: String?

    var provesValidationAdvantage: Bool {
        pureParseSuccess
            && pureIssues.count == testCase.expectedIssueCount
            && yamsParseSuccess
    }

    var object: [String: Any] {
        [
            "id": testCase.id,
            "expectedIssueCount": testCase.expectedIssueCount,
            "provesValidationAdvantage": provesValidationAdvantage,
            "pureyaml": [
                "parseSuccess": pureParseSuccess,
                "validationIssueCount": pureIssues.count,
                "validationIssues": pureIssues.map(issueObject),
                "error": pureError as Any,
            ],
            "yams": [
                "parseSuccess": yamsParseSuccess,
                "documentCount": yamsDocumentCount as Any,
                "error": yamsError as Any,
                "structuredValidationIssues": 0,
            ],
        ]
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: YamsValidation <artifact-json>\n".utf8))
    Foundation.exit(64)
}

let cases = [
    Case(
        id: "root-duplicate-key",
        yaml: """
        title: First
        title: Second
        """,
        expectedIssueCount: 1,
    ),
    Case(
        id: "nested-block-and-flow-duplicates",
        yaml: """
        root:
          title: First
          title: Second
          children:
            - name: One
              name: Two
        flow: {id: one, id: two}
        """,
        expectedIssueCount: 3,
    ),
    Case(
        id: "openapi-path-duplicate",
        yaml: """
        openapi: "3.1.0"
        paths:
          /users:
            get:
              operationId: listUsers
          /users:
            post:
              operationId: createUser
        """,
        expectedIssueCount: 1,
    ),
]

let comparisons = cases.map { testCase in
    let pure = validateWithPureYAML(testCase.yaml)
    let yams = parseWithYams(testCase.yaml)
    return Comparison(
        testCase: testCase,
        pureParseSuccess: pure.parseSuccess,
        pureIssues: pure.issues,
        pureError: pure.error,
        yamsParseSuccess: yams.success,
        yamsDocumentCount: yams.documentCount,
        yamsError: yams.error,
    )
}

let failures = comparisons.filter { !$0.provesValidationAdvantage }
let report: [String: Any] = [
    "summary": [
        "cases": comparisons.count,
        "pureyamlStructuredValidationCases": comparisons.filter { !$0.pureIssues.isEmpty }.count,
        "yamsStructuredValidationCases": 0,
        "failures": failures.count,
    ],
    "comparisons": comparisons.map(\.object),
]

let artifactURL = URL(fileURLWithPath: arguments[1])
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: artifactURL)

print("Yams validation comparison cases: \(comparisons.count)")
print("PureYAML structured validation cases: \(comparisons.filter { !$0.pureIssues.isEmpty }.count)")
print("Yams structured validation cases: 0")
print("Report: \(artifactURL.path)")

if !failures.isEmpty {
    for comparison in failures {
        print("VALIDATION GAP \(comparison.testCase.id)")
        print("  PureYAML parse=\(comparison.pureParseSuccess) issues=\(comparison.pureIssues.count) error=\(comparison.pureError ?? "nil")")
        print("  Yams parse=\(comparison.yamsParseSuccess) docs=\(comparison.yamsDocumentCount.map(String.init) ?? "nil") error=\(comparison.yamsError ?? "nil")")
    }
    Foundation.exit(1)
}

func validateWithPureYAML(_ yaml: String) -> (parseSuccess: Bool, issues: [PureYAML.Validation.Issue], error: String?) {
    do {
        let documents = try PureYAML.parseStream(yaml)
        let result = PureYAML.Validation.Validator().collect(documents)
        return (true, result.issues.map(\.issue), nil)
    } catch {
        return (false, [], String(describing: error))
    }
}

func parseWithYams(_ yaml: String) -> (success: Bool, documentCount: Int?, error: String?) {
    do {
        let documents = try Yams.load_all(yaml: yaml)
        return (true, Array(documents).count, nil)
    } catch {
        return (false, nil, String(describing: error))
    }
}

func issueObject(_ issue: PureYAML.Validation.Issue) -> [String: Any] {
    [
        "severity": issue.severity.description,
        "reason": issue.reason,
        "path": issue.path.description,
        "description": issue.description,
    ]
}
EOF

swift run \
    --package-path "$WORK_DIR" \
    YamsValidation \
    "$ARTIFACT_DIR/yams-validation.json"
