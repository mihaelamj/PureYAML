public extension PureYAML.Validation {
    /// Named YAML source used for batch validation without coupling PureYAML to file IO.
    struct Source: Equatable, Sendable {
        public var name: String
        public var yaml: String

        public init(name: String, yaml: String) {
            self.name = name
            self.yaml = yaml
        }
    }

    /// Non-throwing validation report for one YAML input.
    struct Report: Equatable, Sendable, CustomStringConvertible {
        public var diagnostics: [Diagnostic]

        public init(_ diagnostics: [Diagnostic] = []) {
            self.diagnostics = diagnostics
        }

        public var isEmpty: Bool {
            diagnostics.isEmpty
        }

        public var errors: [Diagnostic] {
            diagnostics.filter { $0.severity == .error }
        }

        public var warnings: [Diagnostic] {
            diagnostics.filter { $0.severity == .warning }
        }

        public var isValid: Bool {
            errors.isEmpty
        }

        public func containsFailures(failOnWarnings: Bool = false) -> Bool {
            failOnWarnings ? !diagnostics.isEmpty : !errors.isEmpty
        }

        public var description: String {
            diagnostics.map(\.description).joined(separator: "\n")
        }
    }

    /// Validation result for one named source in a batch.
    struct SourceReport: Equatable, Sendable {
        public var name: String
        public var report: Report
        public var invalid: Bool

        public init(name: String, report: Report, invalid: Bool) {
            self.name = name
            self.report = report
            self.invalid = invalid
        }
    }

    /// Non-throwing aggregate report for validating many YAML inputs.
    struct BatchReport: Equatable, Sendable, CustomStringConvertible {
        public var sourceReports: [SourceReport]
        public var failOnWarnings: Bool

        public init(
            sourceReports: [SourceReport],
            failOnWarnings: Bool = false,
        ) {
            self.sourceReports = sourceReports
            self.failOnWarnings = failOnWarnings
        }

        public var fileCount: Int {
            sourceReports.count
        }

        public var validCount: Int {
            sourceReports.count(where: { !$0.invalid })
        }

        public var invalidCount: Int {
            sourceReports.count(where: { $0.invalid })
        }

        public var diagnosticCount: Int {
            sourceReports.reduce(0) { count, sourceReport in
                count + sourceReport.report.diagnostics.count
            }
        }

        public var isValid: Bool {
            invalidCount == 0
        }

        public var diagnostics: [Diagnostic] {
            sourceReports.flatMap(\.report.diagnostics)
        }

        public var description: String {
            diagnostics.map(\.description).joined(separator: "\n")
        }

        public func markdownDescription(
            title: String = "PureYAML Validation Report",
        ) -> String {
            var lines: [String] = [
                "# \(title)",
                "",
                "- Files: \(fileCount)",
                "- Valid: \(validCount)",
                "- Invalid: \(invalidCount)",
                "- Diagnostics: \(diagnosticCount)",
                "- Warnings fail: \(failOnWarnings ? "yes" : "no")",
                "",
            ]

            for sourceReport in sourceReports {
                lines.append("## \(sourceReport.name)")
                lines.append("")
                lines.append("Status: \(sourceReport.invalid ? "invalid" : "valid")")
                lines.append("")

                if sourceReport.report.isEmpty {
                    lines.append("No diagnostics.")
                } else {
                    lines.append("```text")
                    lines.append(sourceReport.report.description)
                    lines.append("```")
                }

                lines.append("")
            }

            return lines.joined(separator: "\n")
        }
    }
}

public extension PureYAML {
    /// Parses and validates YAML without throwing, returning parse and validation diagnostics.
    static func validationReport(
        _ yaml: String,
        file: String? = nil,
        using validator: Validation.Validator = .init(),
    ) -> Validation.Report {
        do {
            let documents = try parseStream(yaml)
            let result = validator.collect(documents)
            let diagnostics = result.issues.map { streamIssue in
                Validation.Diagnostic(
                    kind: .validation,
                    severity: streamIssue.issue.severity,
                    file: file,
                    documentIndex: streamIssue.documentIndex,
                    path: streamIssue.issue.path,
                    reason: streamIssue.issue.reason,
                )
            }
            return Validation.Report(diagnostics)
        } catch {
            return Validation.Report([
                Validation.Diagnostic(
                    kind: .parse,
                    severity: .error,
                    file: file,
                    reason: String(describing: error),
                ),
            ])
        }
    }

    /// Validates many YAML inputs without throwing or stopping at the first failure.
    static func validationReports(
        _ sources: [Validation.Source],
        using validator: Validation.Validator = .init(),
        failOnWarnings: Bool = false,
    ) -> Validation.BatchReport {
        let reports = sources.map { source in
            let report = validationReport(source.yaml, file: source.name, using: validator)
            return Validation.SourceReport(
                name: source.name,
                report: report,
                invalid: report.containsFailures(failOnWarnings: failOnWarnings),
            )
        }
        return Validation.BatchReport(sourceReports: reports, failOnWarnings: failOnWarnings)
    }
}
