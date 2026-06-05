@testable import PureYAML
import Testing

struct ValidationValidDocumentCase: CustomStringConvertible {
    var name: String
    var yaml: String

    var description: String {
        name
    }
}

struct ValidationDuplicateKeyCase: CustomStringConvertible {
    var name: String
    var yaml: String
    var expectedIssues: [PureYAML.Validation.Issue]

    var description: String {
        name
    }
}

struct ValidationPathCase: CustomStringConvertible {
    var name: String
    var path: PureYAML.Validation.Path
    var expectedDescription: String
    var isRoot: Bool

    var description: String {
        name
    }
}

func legacyModeRule(severity: PureYAML.Validation.Severity) -> PureYAML.Validation.Rule {
    PureYAML.Validation.Rule(description: "Mode must not be legacy") { context in
        guard case .string("legacy") = context.subject else {
            return []
        }
        return [
            PureYAML.Validation.Issue(
                severity: severity,
                reason: "Legacy mode is not allowed",
                path: context.path,
            ),
        ]
    }
}

func traceRule(label: String) -> PureYAML.Validation.Rule {
    PureYAML.Validation.Rule(description: "Trace \(label)") { context in
        [
            PureYAML.Validation.Issue(
                severity: .warning,
                reason: "\(label) at \(context.path.isRoot ? "root" : context.path.description)",
                path: context.path,
            ),
        ]
    }
}

func expectValidationError(
    _ value: PureYAML.Model.Value,
    using validator: PureYAML.Validation.Validator = .init(),
    strict: Bool = true,
    check: (PureYAML.Validation.Issue.Collection) -> Void,
) {
    do {
        try PureYAML.validate(value, using: validator, strict: strict)
        recordIssue("expected validation failure")
    } catch let collection as PureYAML.Validation.Issue.Collection {
        check(collection)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}
