@testable import PureYAML
import Testing

@Suite("Diagnostic Validation Reports")
struct DiagnosticValidationReportTests {
    @Test("Valid YAML returns parsed artifacts and an empty diagnostic report")
    func test_validYAMLReturnsParsedArtifactsAndEmptyDiagnosticReport() throws {
        let yaml = """
        title: Ready
        metadata:
          owner: Tools
        """

        let report = PureYAML.diagnosticValidationReport(yaml, file: "valid.yaml")
        let value = try PureYAML.parseValidated(yaml, file: "valid.yaml")

        #expect(report == PureYAML.Validation.Report())
        #expect(value == .mapping(.init([
            .init(key: "title", value: .string("Ready")),
            .init(key: "metadata", value: .mapping(.init([
                .init(key: "owner", value: .string("Tools")),
            ]))),
        ])))
    }

    @Test("Diagnostic reports combine preflight warnings with model validation errors")
    func test_diagnosticReportsCombinePreflightWarningsWithModelValidationErrors() {
        let report = PureYAML.diagnosticValidationReport(
            [
                "title: First",
                "title: Second",
                "note: ok  ",
            ].joined(separator: "\n"),
            file: "duplicates.yaml",
        )

        #expect(report.diagnostics == [
            .init(
                kind: .parse,
                code: "trailingWhitespace",
                severity: .warning,
                file: "duplicates.yaml",
                line: 3,
                column: 9,
                reason: "trailing whitespace",
            ),
            .init(
                kind: .validation,
                severity: .error,
                file: "duplicates.yaml",
                documentIndex: 0,
                path: .init([.key("title")]),
                reason: "Duplicate mapping key 'title'",
            ),
        ])
        #expect(!report.isValid)
        #expect(report.warnings.count == 1)
        #expect(report.errors.count == 1)
    }

    @Test("Diagnostic reports keep scanning after lines that will make parsing fail")
    func test_diagnosticReportsKeepScanningAfterLinesThatWillMakeParsingFail() {
        let report = PureYAML.diagnosticValidationReport(
            [
                "title: \"open",
                "summary:Missing",
                "\tmetadata:",
            ].joined(separator: "\n"),
            file: "broken.yaml",
        )

        #expect(report.diagnostics == [
            .init(
                kind: .parse,
                code: "missingMappingSpace",
                severity: .error,
                file: "broken.yaml",
                line: 2,
                column: 9,
                reason: "missing space after ':' in mapping entry",
            ),
            .init(
                kind: .parse,
                code: "tabIndentation",
                severity: .error,
                file: "broken.yaml",
                line: 3,
                column: 1,
                reason: "tab used for indentation; YAML indentation must use spaces",
            ),
            .init(
                kind: .parse,
                code: "unterminatedQuotedString",
                severity: .error,
                file: "broken.yaml",
                line: 1,
                reason: "unterminated quoted string at line 1",
            ),
        ])
        #expect(report.description == [
            "broken.yaml: line 2, column 9: error: parse: missing space after ':' in mapping entry",
            "broken.yaml: line 3, column 1: error: parse: tab used for indentation; YAML indentation must use spaces",
            "broken.yaml: line 1: error: parse: unterminated quoted string at line 1",
        ].joined(separator: "\n"))
    }

    @Test("Report errors carry machine-readable validation bodies")
    func test_reportErrorsCarryMachineReadableValidationBodies() throws {
        do {
            _ = try PureYAML.parseValidated(
                [
                    "title: \"open",
                    "summary:Missing",
                    "\tmetadata:",
                ].joined(separator: "\n"),
                file: "broken.yaml",
            )
            recordIssue("expected validation report error")
        } catch let error as PureYAML.Validation.ReportError {
            let json = error.report.jsonDescription(title: "Production YAML Validation")
            let yaml = error.report.yamlDescription(title: "Production YAML Validation")

            #expect(error.report.diagnostics.count == 3)
            #expect(json.contains(#""title": "Production YAML Validation""#))
            #expect(json.contains(#""code": "missingMappingSpace""#))
            #expect(json.contains(#""line": 2"#))
            #expect(json.contains(#""column": 9"#))
            #expect(json.contains(#""reason": "missing space after ':' in mapping entry""#))

            let yamlRoot = try requireMapping(PureYAML.parse(yaml))
            let diagnostics = yamlRoot?.sequence("diagnostics")
            let firstDiagnostic = diagnostics?.first?.mapping

            #expect(yamlRoot?["title"] == PureYAML.Model.Value.string("Production YAML Validation"))
            #expect(yamlRoot?["summary"]?.mapping?["valid"] == PureYAML.Model.Value.bool(false))
            #expect(yamlRoot?["summary"]?.mapping?["diagnostics"] == PureYAML.Model.Value.int(3))
            #expect(yamlRoot?["summary"]?.mapping?["errors"] == PureYAML.Model.Value.int(3))
            #expect(yamlRoot?["summary"]?.mapping?["warnings"] == PureYAML.Model.Value.int(0))
            #expect(firstDiagnostic?["code"] == PureYAML.Model.Value.string("missingMappingSpace"))
            #expect(firstDiagnostic?["line"] == PureYAML.Model.Value.int(2))
            #expect(firstDiagnostic?["column"] == PureYAML.Model.Value.int(9))
            #expect(firstDiagnostic?["reason"] == PureYAML.Model.Value.string("missing space after ':' in mapping entry"))
        } catch {
            recordIssue("unexpected error \(error)")
        }
    }

    @Test("Diagnostic batch reports can treat preflight warnings as failures")
    func test_diagnosticBatchReportsCanTreatPreflightWarningsAsFailures() {
        let report = PureYAML.diagnosticValidationReports(
            [
                .init(name: "valid.yaml", yaml: "title: Ready"),
                .init(name: "warning.yaml", yaml: "title: Ready  "),
            ],
            failOnWarnings: true,
        )

        #expect(report.fileCount == 2)
        #expect(report.validCount == 1)
        #expect(report.invalidCount == 1)
        #expect(report.diagnosticCount == 1)
        #expect(report.sourceReports.map(\.invalid) == [false, true])
        #expect(report.diagnostics == [
            .init(
                kind: .parse,
                code: "trailingWhitespace",
                severity: .warning,
                file: "warning.yaml",
                line: 1,
                column: 13,
                reason: "trailing whitespace",
            ),
        ])
    }

    @Test("Malformed production-shaped YAML reports ten or more structured diagnostics")
    func test_malformedProductionShapedYAMLReportsTenOrMoreStructuredDiagnostics() {
        let report = PureYAML.diagnosticValidationReport(
            [
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
            file: "production-broken.yaml",
        )

        #expect(report.diagnostics.count == 11)
        #expect(report.errors.count == 9)
        #expect(report.warnings.count == 2)
        #expect(report.diagnostics.map(\.code) == [
            "missingMappingSpace",
            "tabIndentation",
            "missingSequenceSpace",
            "trailingWhitespace",
            "missingMappingSpace",
            "tabIndentation",
            "missingSequenceSpace",
            "missingMappingSpace",
            "trailingWhitespace",
            "missingMappingSpace",
            "unterminatedQuotedString",
        ])
        #expect(report.diagnostics.first == .init(
            kind: .parse,
            code: "missingMappingSpace",
            severity: .error,
            file: "production-broken.yaml",
            line: 1,
            column: 12,
            reason: "missing space after ':' in mapping entry",
        ))
        #expect(report.diagnostics.last == .init(
            kind: .parse,
            code: "unterminatedQuotedString",
            severity: .error,
            file: "production-broken.yaml",
            line: 11,
            reason: "unterminated quoted string at line 11",
        ))
    }
}
