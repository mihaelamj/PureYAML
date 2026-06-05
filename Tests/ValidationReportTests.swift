import Foundation
@testable import PureYAML
import Testing

@Suite("Validation Reports")
struct ValidationReportTests {
    @Test("Valid YAML returns an empty report")
    func test_validYAMLReturnsEmptyReport() {
        let report = PureYAML.validationReport("title: Ready", file: "valid.yaml")

        #expect(report.isEmpty)
        #expect(report.isValid)
        #expect(report.description == "")
    }

    @Test("Parse failures return file-scoped diagnostics")
    func test_parseFailuresReturnFileScopedDiagnostics() {
        let report = PureYAML.validationReport("title: \"open", file: "broken.yaml")

        #expect(report.diagnostics == [
            .init(
                kind: .parse,
                severity: .error,
                file: "broken.yaml",
                reason: "unterminated quoted string at line 1",
            ),
        ])
        #expect(!report.isValid)
        #expect(report.description == "broken.yaml: error: parse: unterminated quoted string at line 1")
    }

    @Test("Duplicate keys return document and path diagnostics")
    func test_duplicateKeysReturnDocumentAndPathDiagnostics() {
        let report = PureYAML.validationReport(
            """
            title: First
            title: Second
            """,
            file: "duplicates.yaml",
        )

        #expect(report.diagnostics == [
            .init(
                kind: .validation,
                severity: .error,
                file: "duplicates.yaml",
                documentIndex: 0,
                path: .init([.key("title")]),
                reason: "Duplicate mapping key 'title'",
            ),
        ])
        #expect(report.description == "duplicates.yaml: document[0]: $.title: error: validation: Duplicate mapping key 'title'")
    }

    @Test("Warning reports stay visible without making the report invalid")
    func test_warningReportsStayVisibleWithoutMakingReportInvalid() {
        let validator = PureYAML.Validation.Validator.blank.validating(
            PureYAML.Validation.Rule(
                description: "Mode is not legacy",
                severity: .warning,
                check: { context in context.subject != .string("legacy") },
                when: { context in context.path.components.last == .key("mode") },
            ),
        )

        let report = PureYAML.validationReport("mode: legacy", file: "warnings.yaml", using: validator)

        #expect(report.diagnostics == [
            .init(
                kind: .validation,
                severity: .warning,
                file: "warnings.yaml",
                documentIndex: 0,
                path: .init([.key("mode")]),
                reason: "Failed to satisfy: Mode is not legacy",
            ),
        ])
        #expect(report.isValid)
        #expect(report.warnings.count == 1)
        #expect(report.errors.isEmpty)
    }

    @Test("Batch reports collect every source without stopping at the first failure")
    func test_batchReportsCollectEverySourceWithoutStoppingAtFirstFailure() {
        let validator = PureYAML.Validation.Validator().validating(
            PureYAML.Validation.Rule(
                description: "Mode is not legacy",
                severity: .warning,
                check: { context in context.subject != .string("legacy") },
                when: { context in context.path.components.last == .key("mode") },
            ),
        )

        let report = PureYAML.validationReports(
            [
                .init(name: "valid.yaml", yaml: "title: Ready"),
                .init(name: "broken.yaml", yaml: "title: \"open"),
                .init(
                    name: "duplicates.yaml",
                    yaml: """
                    title: First
                    title: Second
                    """,
                ),
                .init(name: "warnings.yaml", yaml: "mode: legacy"),
            ],
            using: validator,
        )

        #expect(report.fileCount == 4)
        #expect(report.validCount == 2)
        #expect(report.invalidCount == 2)
        #expect(report.diagnosticCount == 3)
        #expect(!report.isValid)
        #expect(report.description == [
            "broken.yaml: error: parse: unterminated quoted string at line 1",
            "duplicates.yaml: document[0]: $.title: error: validation: Duplicate mapping key 'title'",
            "warnings.yaml: document[0]: $.mode: warning: validation: Failed to satisfy: Mode is not legacy",
        ].joined(separator: "\n"))
        #expect(report.sourceReports.map(\.name) == [
            "valid.yaml",
            "broken.yaml",
            "duplicates.yaml",
            "warnings.yaml",
        ])
        #expect(report.sourceReports.map(\.invalid) == [false, true, true, false])
    }

    @Test("Batch reports can treat warnings as failures")
    func test_batchReportsCanTreatWarningsAsFailures() {
        let validator = PureYAML.Validation.Validator.blank.validating(
            PureYAML.Validation.Rule(
                description: "Mode is not legacy",
                severity: .warning,
                check: { context in context.subject != .string("legacy") },
                when: { context in context.path.components.last == .key("mode") },
            ),
        )

        let report = PureYAML.validationReports(
            [
                .init(name: "warnings.yaml", yaml: "mode: legacy"),
            ],
            using: validator,
            failOnWarnings: true,
        )

        #expect(report.failOnWarnings)
        #expect(report.fileCount == 1)
        #expect(report.validCount == 0)
        #expect(report.invalidCount == 1)
        #expect(!report.isValid)
        #expect(report.sourceReports == [
            .init(
                name: "warnings.yaml",
                report: .init([
                    .init(
                        kind: .validation,
                        severity: .warning,
                        file: "warnings.yaml",
                        documentIndex: 0,
                        path: .init([.key("mode")]),
                        reason: "Failed to satisfy: Mode is not legacy",
                    ),
                ]),
                invalid: true,
            ),
        ])
    }

    @Test("Batch reports render exact Markdown file contents")
    func test_batchReportsRenderExactMarkdownFileContents() throws {
        let report = makeMarkdownValidationReport()
        let expected = expectedMarkdownValidationReport

        #expect(report.markdownDescription(title: "YAML Production Validation") == expected)

        #expect(try writeAndRead(report: report) == expected)
    }
}

private func makeMarkdownValidationReport() -> PureYAML.Validation.BatchReport {
    PureYAML.validationReports(
        [
            .init(name: "valid.yaml", yaml: "title: Ready"),
            .init(name: "broken.yaml", yaml: "title: \"open"),
            .init(
                name: "duplicates.yaml",
                yaml: """
                title: First
                title: Second
                """,
            ),
        ],
    )
}

private func writeAndRead(report: PureYAML.Validation.BatchReport) throws -> String {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "PureYAMLValidationReport-\(UUID().uuidString)",
        isDirectory: true,
    )
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let file = directory.appendingPathComponent("validation-report.md")
    try report.markdownDescription(title: "YAML Production Validation")
        .write(to: file, atomically: true, encoding: .utf8)
    return try String(contentsOf: file, encoding: .utf8)
}

private let expectedMarkdownValidationReport = """
# YAML Production Validation

- Files: 3
- Valid: 1
- Invalid: 2
- Diagnostics: 2
- Warnings fail: no

## valid.yaml

Status: valid

No diagnostics.

## broken.yaml

Status: invalid

```text
broken.yaml: error: parse: unterminated quoted string at line 1
```

## duplicates.yaml

Status: invalid

```text
duplicates.yaml: document[0]: $.title: error: validation: Duplicate mapping key 'title'
```

"""
