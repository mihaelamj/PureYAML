#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.build/yams-diagnostics"
ARTIFACT_DIR="$ROOT_DIR/.build/pureyaml-artifacts/diagnostics"

mkdir -p "$WORK_DIR/Sources/YamsDiagnostics" "$ARTIFACT_DIR"

cat > "$WORK_DIR/Package.swift" <<EOF
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PureYAMLYamsDiagnostics",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "$ROOT_DIR"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "YamsDiagnostics",
            dependencies: [
                "PureYAML",
                .product(name: "Yams", package: "Yams"),
            ],
        ),
    ],
)
EOF

cat > "$WORK_DIR/Sources/YamsDiagnostics/main.swift" <<'EOF'
import Foundation
import PureYAML
import Yams

struct Case {
    var id: String
    var yaml: String
    var expectedCodes: [String]
}

struct Comparison {
    var testCase: Case
    var pureDiagnostics: [PureYAML.Validation.Diagnostic]
    var yamsSuccess: Bool
    var yamsDocumentCount: Int?
    var yamsError: String?

    var hasExpectedCodes: Bool {
        let codes = Set(pureDiagnostics.compactMap(\.code))
        return testCase.expectedCodes.allSatisfy { codes.contains($0) }
    }

    var object: [String: Any] {
        [
            "id": testCase.id,
            "expectedCodes": testCase.expectedCodes,
            "pureyaml": [
                "diagnostics": pureDiagnostics.map(diagnosticObject),
                "diagnosticCount": pureDiagnostics.count,
                "errorCount": pureDiagnostics.filter { $0.severity == .error }.count,
                "warningCount": pureDiagnostics.filter { $0.severity == .warning }.count,
                "hasExpectedCodes": hasExpectedCodes,
            ],
            "yams": [
                "success": yamsSuccess,
                "documentCount": yamsDocumentCount as Any,
                "error": yamsError as Any,
                "structuredDiagnostics": false,
            ],
        ]
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: YamsDiagnostics <artifact-json>\n".utf8))
    Foundation.exit(64)
}

let artifactURL = URL(fileURLWithPath: arguments[1])
let cases = [
    Case(
        id: "missing-mapping-space",
        yaml: "apiVersion:v1\nkind: Pod\n",
        expectedCodes: ["missingMappingSpace"],
    ),
    Case(
        id: "tab-indentation",
        yaml: "root:\n\tchild: value\n",
        expectedCodes: ["tabIndentation"],
    ),
    Case(
        id: "missing-sequence-space",
        yaml: "-bad\n- ok\n",
        expectedCodes: ["missingSequenceSpace"],
    ),
    Case(
        id: "unterminated-quoted-string",
        yaml: "title: \"open\nsummary: still scanned\n",
        expectedCodes: ["unterminatedQuotedString"],
    ),
    Case(
        id: "production-shaped-batch",
        yaml: [
            "apiVersion:v1",
            "\tmetadata:",
            "-bad",
            "name: demo  ",
            "image:nginx",
            "\t- item",
            "-item",
            "version:1",
            "ports: [80]\t",
            "owner:team",
            "title: \"open",
        ].joined(separator: "\n"),
        expectedCodes: [
            "missingMappingSpace",
            "tabIndentation",
            "missingSequenceSpace",
            "trailingWhitespace",
            "unterminatedQuotedString",
        ],
    ),
]

let comparisons = cases.map { testCase in
    let report = PureYAML.diagnosticValidationReport(testCase.yaml, file: "\(testCase.id).yaml")
    let yams = parseWithYams(testCase.yaml)
    return Comparison(
        testCase: testCase,
        pureDiagnostics: report.diagnostics,
        yamsSuccess: yams.success,
        yamsDocumentCount: yams.documentCount,
        yamsError: yams.error,
    )
}

let failures = comparisons.filter { $0.pureDiagnostics.isEmpty || !$0.hasExpectedCodes }
let report: [String: Any] = [
    "summary": [
        "cases": comparisons.count,
        "pureyamlStructuredCases": comparisons.filter { !$0.pureDiagnostics.isEmpty }.count,
        "pureyamlCasesWithExpectedCodes": comparisons.filter(\.hasExpectedCodes).count,
        "yamsStructuredCases": 0,
        "failures": failures.count,
    ],
    "comparisons": comparisons.map(\.object),
]

let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: artifactURL)

print("Yams diagnostic comparison cases: \(comparisons.count)")
print("PureYAML structured cases: \(comparisons.filter { !$0.pureDiagnostics.isEmpty }.count)")
print("PureYAML cases with expected codes: \(comparisons.filter(\.hasExpectedCodes).count)")
print("Yams structured cases: 0")
print("Report: \(artifactURL.path)")

if !failures.isEmpty {
    for comparison in failures {
        print("DIAGNOSTIC GAP \(comparison.testCase.id)")
        print("  expected codes: \(comparison.testCase.expectedCodes.joined(separator: ", "))")
        print("  actual codes: \(comparison.pureDiagnostics.compactMap(\.code).joined(separator: ", "))")
    }
    Foundation.exit(1)
}

func parseWithYams(_ yaml: String) -> (success: Bool, documentCount: Int?, error: String?) {
    do {
        let documents = try Yams.load_all(yaml: yaml)
        return (true, Array(documents).count, nil)
    } catch {
        return (false, nil, String(describing: error))
    }
}

func diagnosticObject(_ diagnostic: PureYAML.Validation.Diagnostic) -> [String: Any] {
    [
        "kind": diagnostic.kind.description,
        "code": diagnostic.code as Any,
        "severity": diagnostic.severity.description,
        "file": diagnostic.file as Any,
        "line": diagnostic.line as Any,
        "column": diagnostic.column as Any,
        "documentIndex": diagnostic.documentIndex as Any,
        "path": diagnostic.path?.description as Any,
        "reason": diagnostic.reason,
        "description": diagnostic.description,
    ]
}
EOF

swift run \
    --package-path "$WORK_DIR" \
    YamsDiagnostics \
    "$ARTIFACT_DIR/yams-diagnostics.json"
