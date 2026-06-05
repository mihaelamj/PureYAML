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
                severity: .error,
                file: "broken.yaml",
                line: 2,
                column: 9,
                reason: "missing space after ':' in mapping entry",
            ),
            .init(
                kind: .parse,
                severity: .error,
                file: "broken.yaml",
                line: 3,
                column: 1,
                reason: "tab used for indentation; YAML indentation must use spaces",
            ),
            .init(
                kind: .parse,
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
                severity: .warning,
                file: "warning.yaml",
                line: 1,
                column: 13,
                reason: "trailing whitespace",
            ),
        ])
    }
}
