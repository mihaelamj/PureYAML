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

        public func modelValue() -> PureYAML.Model.Value {
            .sequence(diagnostics.map(\.modelValue))
        }

        public func modelValue(
            title: String = "PureYAML Validation Report",
        ) -> PureYAML.Model.Value {
            .mapping(.init([
                .init(key: "title", value: .string(title)),
                .init(key: "summary", value: summaryModelValue),
                .init(key: "diagnostics", value: modelValue()),
            ]))
        }

        public func yamlDescription(
            title: String = "PureYAML Validation Report",
        ) -> String {
            PureYAML.dump(modelValue(title: title))
        }

        public func jsonDescription(
            title: String = "PureYAML Validation Report",
        ) -> String {
            modelValue(title: title).jsonDescription + "\n"
        }

        private var summaryModelValue: PureYAML.Model.Value {
            .mapping(.init([
                .init(key: "valid", value: .bool(isValid)),
                .init(key: "diagnostics", value: .int(diagnostics.count)),
                .init(key: "errors", value: .int(errors.count)),
                .init(key: "warnings", value: .int(warnings.count)),
            ]))
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

        public func modelValue() -> PureYAML.Model.Value {
            .mapping(.init([
                .init(key: "name", value: .string(name)),
                .init(key: "status", value: .string(invalid ? "invalid" : "valid")),
                .init(key: "invalid", value: .bool(invalid)),
                .init(key: "diagnostics", value: report.modelValue()),
            ]))
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

        public func modelValue(
            title: String = "PureYAML Validation Report",
        ) -> PureYAML.Model.Value {
            .mapping(.init([
                .init(key: "title", value: .string(title)),
                .init(key: "summary", value: summaryModelValue),
                .init(key: "sources", value: .sequence(sourceReports.map { $0.modelValue() })),
            ]))
        }

        public func yamlDescription(
            title: String = "PureYAML Validation Report",
        ) -> String {
            PureYAML.dump(modelValue(title: title))
        }

        public func jsonDescription(
            title: String = "PureYAML Validation Report",
        ) -> String {
            modelValue(title: title).jsonDescription + "\n"
        }

        private var summaryModelValue: PureYAML.Model.Value {
            .mapping(.init([
                .init(key: "files", value: .int(fileCount)),
                .init(key: "valid", value: .int(validCount)),
                .init(key: "invalid", value: .int(invalidCount)),
                .init(key: "diagnostics", value: .int(diagnosticCount)),
                .init(key: "warningsFail", value: .bool(failOnWarnings)),
            ]))
        }
    }
}

private extension PureYAML.Validation.Diagnostic {
    var modelValue: PureYAML.Model.Value {
        var pairs: [PureYAML.Model.Pair] = [
            .init(key: "kind", value: .string(kind.description)),
            .init(key: "severity", value: .string(severity.description)),
            .init(key: "file", value: file.map(PureYAML.Model.Value.string) ?? .null),
        ]
        if let line {
            pairs.append(.init(key: "line", value: .int(line)))
        }
        if let column {
            pairs.append(.init(key: "column", value: .int(column)))
        }
        pairs.append(contentsOf: [
            .init(key: "documentIndex", value: documentIndex.map(PureYAML.Model.Value.int) ?? .null),
            .init(key: "path", value: path.map { .string($0.isRoot ? "root" : $0.description) } ?? .null),
            .init(key: "reason", value: .string(reason)),
            .init(key: "description", value: .string(description)),
        ])
        return .mapping(.init(pairs))
    }
}

private extension PureYAML.Model.Value {
    var jsonDescription: String {
        jsonDescription(indentation: 0)
    }

    func jsonDescription(indentation: Int) -> String {
        switch self {
        case .null:
            "null"
        case let .bool(value):
            value ? "true" : "false"
        case let .int(value):
            String(value)
        case let .double(value):
            value.isFinite ? String(value) : "null"
        case let .string(value):
            value.jsonEscaped
        case let .sequence(values):
            values.jsonDescription(indentation: indentation)
        case let .mapping(mapping):
            mapping.jsonDescription(indentation: indentation)
        }
    }
}

private extension [PureYAML.Model.Value] {
    func jsonDescription(indentation: Int) -> String {
        guard !isEmpty else {
            return "[]"
        }

        let nextIndentation = indentation + 2
        let lines = map { value in
            "\(String.spaces(nextIndentation))\(value.jsonDescription(indentation: nextIndentation))"
        }
        return "[\n\(lines.joined(separator: ",\n"))\n\(String.spaces(indentation))]"
    }
}

private extension PureYAML.Model.Mapping {
    func jsonDescription(indentation: Int) -> String {
        guard !pairs.isEmpty else {
            return "{}"
        }

        let nextIndentation = indentation + 2
        let lines = pairs.map { pair in
            let value = pair.value.jsonDescription(indentation: nextIndentation)
            return "\(String.spaces(nextIndentation))\(pair.key.jsonEscaped): \(value)"
        }
        return "{\n\(lines.joined(separator: ",\n"))\n\(String.spaces(indentation))}"
    }
}

private extension String {
    static func spaces(_ count: Int) -> String {
        String(repeating: " ", count: count)
    }

    var jsonEscaped: String {
        var output = "\""
        for scalar in unicodeScalars {
            switch scalar.value {
            case 0x08:
                output += "\\b"
            case 0x09:
                output += "\\t"
            case 0x0A:
                output += "\\n"
            case 0x0C:
                output += "\\f"
            case 0x0D:
                output += "\\r"
            case 0x22:
                output += "\\\""
            case 0x5C:
                output += "\\\\"
            case 0x00 ... 0x1F:
                output += scalar.value.jsonControlEscape
            default:
                output.unicodeScalars.append(scalar)
            }
        }
        output += "\""
        return output
    }
}

private extension UInt32 {
    var jsonControlEscape: String {
        let digits = Array("0123456789abcdef")
        return "\\u" + stride(from: 12, through: 0, by: -4).map { shift in
            String(digits[Int((self >> UInt32(shift)) & 0xF)])
        }.joined()
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
