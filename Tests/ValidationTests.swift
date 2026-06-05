@testable import PureYAML
import Testing

@Suite("Validation")
struct ValidationTests {
    @Test("Validates documents with default rules")
    func validatesDocumentsWithDefaultRules() throws {
        let value = try PureYAML.parse(
            """
            title: Example
            active: true
            """,
        )

        #expect(try PureYAML.validate(value).isEmpty)
    }

    @Test("Reports duplicate mapping keys")
    func reportsDuplicateMappingKeys() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))

        do {
            try PureYAML.validate(value)
            recordIssue("expected duplicate key validation failure")
        } catch let collection as PureYAML.Validation.Issue.Collection {
            #expect(collection.issues == [
                PureYAML.Validation.Issue(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
            ])
        } catch {
            recordIssue("unexpected error \(error)")
        }
    }

    @Test("Reports nested validation paths")
    func reportsNestedValidationPaths() throws {
        let value = try PureYAML.parse(
            """
            routes:
              - name: Users
                name: People
            """,
        )

        let result = PureYAML.Validation.Validator().collect(value)

        #expect(result.errors.map(\.path.description) == ["$.routes[0].name"])
    }

    @Test("Blank validator disables default rules")
    func blankValidatorDisablesDefaultRules() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))

        #expect(try PureYAML.validate(value, using: .blank).isEmpty)
    }

    @Test("Custom validation rules can be added")
    func customValidationRulesCanBeAdded() throws {
        let value = try PureYAML.parse(
            """
            mode: legacy
            """,
        )
        let validator = PureYAML.Validation.Validator.blank.validating(legacyModeRule(severity: .error))

        do {
            try PureYAML.validate(value, using: validator)
            recordIssue("expected custom validation failure")
        } catch let collection as PureYAML.Validation.Issue.Collection {
            #expect(collection.issues.map(\.path.description) == ["$.mode"])
            #expect(collection.issues.map(\.reason) == ["Legacy mode is not allowed"])
        } catch {
            recordIssue("unexpected error \(error)")
        }
    }

    @Test("Strict validation treats warnings as failures")
    func strictValidationTreatsWarningsAsFailures() throws {
        let value = try PureYAML.parse("mode: legacy")
        let validator = PureYAML.Validation.Validator.blank.validating(legacyModeRule(severity: .warning))

        do {
            try PureYAML.validate(value, using: validator)
            recordIssue("expected warning to fail strict validation")
        } catch let collection as PureYAML.Validation.Issue.Collection {
            #expect(collection.issues.map(\.severity) == [.warning])
        } catch {
            recordIssue("unexpected error \(error)")
        }
    }

    @Test("Non-strict validation returns warnings")
    func nonStrictValidationReturnsWarnings() throws {
        let value = try PureYAML.parse("mode: legacy")
        let validator = PureYAML.Validation.Validator.blank.validating(legacyModeRule(severity: .warning))

        let warnings = try PureYAML.validate(value, using: validator, strict: false)

        #expect(warnings == [
            PureYAML.Validation.Issue(
                severity: .warning,
                reason: "Legacy mode is not allowed",
                path: .init([.key("mode")]),
            ),
        ])
    }

    @Test("Validation result separates errors and warnings")
    func validationResultSeparatesErrorsAndWarnings() {
        let result = PureYAML.Validation.Result([
            .init(severity: .error, reason: "error"),
            .init(severity: .warning, reason: "warning"),
        ])

        #expect(result.isValid == false)
        #expect(result.errors.map(\.reason) == ["error"])
        #expect(result.warnings.map(\.reason) == ["warning"])
    }

    @Test("Validation paths describe roots, keys, and indexes")
    func validationPathsDescribeRootsKeysAndIndexes() {
        let path = PureYAML.Validation.Path.root
            .appending(.key("routes"))
            .appending(.index(1))
            .appending(.key("name"))

        #expect(PureYAML.Validation.Path.root.description == "$")
        #expect(PureYAML.Validation.Path.root.isRoot)
        #expect(path.description == "$.routes[1].name")
    }

    @Test("Validation issue descriptions include severity reason and path")
    func validationIssueDescriptionsIncludeSeverityReasonAndPath() {
        let issue = PureYAML.Validation.Issue(
            severity: .error,
            reason: "Duplicate mapping key 'title'",
            path: .init([.key("title")]),
        )

        #expect(issue.description == "error: Duplicate mapping key 'title' at $.title")
    }

    private func legacyModeRule(severity: PureYAML.Validation.Severity) -> PureYAML.Validation.Rule {
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
}
