public extension PureYAML {
    /// Parses and validates YAML after collecting full-text diagnostics.
    static func diagnosticValidationReport(
        _ yaml: String,
        file: String? = nil,
        using validator: Validation.Validator = .init(),
        preflightScanner: Validation.PreflightScanner = .init(),
    ) -> Validation.Report {
        diagnosticValidationResult(
            yaml,
            file: file,
            using: validator,
            preflightScanner: preflightScanner,
        ).report
    }

    /// Validates many YAML inputs with preflight diagnostics for damaged input.
    static func diagnosticValidationReports(
        _ sources: [Validation.Source],
        using validator: Validation.Validator = .init(),
        failOnWarnings: Bool = false,
        preflightScanner: Validation.PreflightScanner = .init(),
    ) -> Validation.BatchReport {
        let sourceReports = sources.map { source in
            let report = diagnosticValidationReport(
                source.yaml,
                file: source.name,
                using: validator,
                preflightScanner: preflightScanner,
            )
            return Validation.SourceReport(
                name: source.name,
                report: report,
                invalid: report.containsFailures(failOnWarnings: failOnWarnings),
            )
        }
        return Validation.BatchReport(sourceReports: sourceReports, failOnWarnings: failOnWarnings)
    }

    /// Parses a YAML document and throws ``Validation/ReportError`` on failure.
    static func parseValidated(
        _ yaml: String,
        file: String? = nil,
        using validator: Validation.Validator = .init(),
        preflightScanner: Validation.PreflightScanner = .init(),
    ) throws -> Model.Value {
        let documents = try parseValidatedStream(
            yaml,
            file: file,
            using: validator,
            preflightScanner: preflightScanner,
        )
        return documents.first?.value ?? .null
    }

    /// Parses a YAML stream and throws ``Validation/ReportError`` on failure.
    static func parseValidatedStream(
        _ yaml: String,
        file: String? = nil,
        using validator: Validation.Validator = .init(),
        preflightScanner: Validation.PreflightScanner = .init(),
    ) throws -> [Stream.Document] {
        let result = diagnosticValidationResult(
            yaml,
            file: file,
            using: validator,
            preflightScanner: preflightScanner,
        )
        guard result.report.isValid, let documents = result.documents else {
            throw Validation.ReportError(report: result.report)
        }
        return documents
    }
}

private struct DiagnosticValidationResult {
    var documents: [PureYAML.Stream.Document]?
    var report: PureYAML.Validation.Report
}

private extension PureYAML {
    static func diagnosticValidationResult(
        _ yaml: String,
        file: String?,
        using validator: Validation.Validator,
        preflightScanner: Validation.PreflightScanner,
    ) -> DiagnosticValidationResult {
        var diagnostics = preflightScanner.diagnostics(in: yaml, file: file)

        do {
            let documents = try parseStream(yaml)
            let result = validator.collect(documents)
            diagnostics.append(contentsOf: result.issues.map { streamIssue in
                Validation.Diagnostic(
                    kind: .validation,
                    severity: streamIssue.issue.severity,
                    file: file,
                    documentIndex: streamIssue.documentIndex,
                    path: streamIssue.issue.path,
                    reason: streamIssue.issue.reason,
                )
            })
            return DiagnosticValidationResult(
                documents: documents,
                report: Validation.Report(diagnostics),
            )
        } catch let error as Parsing.ParseError {
            diagnostics.append(Validation.Diagnostic(
                kind: .parse,
                severity: .error,
                file: file,
                line: error.line,
                column: error.column,
                reason: error.description,
            ))
            return DiagnosticValidationResult(
                documents: nil,
                report: Validation.Report(diagnostics),
            )
        } catch {
            diagnostics.append(Validation.Diagnostic(
                kind: .parse,
                severity: .error,
                file: file,
                reason: String(describing: error),
            ))
            return DiagnosticValidationResult(
                documents: nil,
                report: Validation.Report(diagnostics),
            )
        }
    }
}

private extension PureYAML.Parsing.ParseError {
    var line: Int? {
        switch self {
        case .emptyDocument:
            nil
        case let .tabIndentation(line),
             let .unexpectedIndentation(line),
             let .mixedCollectionStyles(line),
             let .expectedMappingKey(line),
             let .expectedAnchorName(line),
             let .expectedAliasName(line),
             let .incompatibleYAMLDirective(line),
             let .unterminatedTag(line),
             let .unterminatedQuotedString(line),
             let .unsupportedDirective(_, line),
             let .unsupportedMultiDocumentStream(line):
            line
        case let .expectedNode(line, _),
             let .expectedScalarKey(line, _),
             let .invalidTaggedScalar(_, _, line, _),
             let .invalidMergeValue(line, _),
             let .undefinedAlias(_, line, _),
             let .unexpectedEvent(_, _, line, _),
             let .unexpectedToken(_, _, line, _):
            line
        }
    }

    var column: Int? {
        switch self {
        case .emptyDocument,
             .tabIndentation,
             .unexpectedIndentation,
             .mixedCollectionStyles,
             .expectedMappingKey,
             .expectedAnchorName,
             .expectedAliasName,
             .incompatibleYAMLDirective,
             .unterminatedTag,
             .unterminatedQuotedString,
             .unsupportedDirective,
             .unsupportedMultiDocumentStream:
            nil
        case let .expectedNode(_, column),
             let .expectedScalarKey(_, column),
             let .invalidTaggedScalar(_, _, _, column),
             let .invalidMergeValue(_, column),
             let .undefinedAlias(_, _, column),
             let .unexpectedEvent(_, _, _, column),
             let .unexpectedToken(_, _, _, column):
            column
        }
    }
}
