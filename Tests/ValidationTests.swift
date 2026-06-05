@testable import PureYAML
import Testing

@Suite("Validation")
struct ValidationTests {
    @Test("Validates documents with default rules")
    func test_documentsWithDefaultRules() throws {
        let value = try PureYAML.parse(
            """
            title: Example
            active: true
            """,
        )

        #expect(try PureYAML.validate(value).isEmpty)
    }

    @Test("Reports duplicate mapping keys")
    func test_duplicateMappingKeyError() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))

        expectValidationError(value) { collection in
            #expect(collection.issues == [
                PureYAML.Validation.Issue(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
            ])
        }
    }

    @Test("Reports nested validation paths")
    func test_nestedValidationPaths() throws {
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

    @Test("Rejects duplicate mapping keys parsed through the event composer")
    func test_parsedDuplicateMappingKeyError() throws {
        let value = try PureYAML.parse(
            """
            title: First
            title: Second
            """,
        )

        expectValidationError(value) { collection in
            #expect(collection.issues == [
                PureYAML.Validation.Issue(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
            ])
        }
    }

    @Test("Blank validator disables default rules")
    func test_blankValidatorDisablesDefaultRules() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))

        #expect(try PureYAML.validate(value, using: .blank).isEmpty)
    }

    @Test("Custom validation rules can be added")
    func test_customValidationRuleError() throws {
        let value = try PureYAML.parse(
            """
            mode: legacy
            """,
        )
        let validator = PureYAML.Validation.Validator.blank.validating(legacyModeRule(severity: .error))

        expectValidationError(value, using: validator) { collection in
            #expect(collection.issues.map(\.path.description) == ["$.mode"])
            #expect(collection.issues.map(\.reason) == ["Legacy mode is not allowed"])
        }
    }

    @Test("Strict validation treats warnings as failures")
    func test_strictValidationTreatsWarningsAsFailures() throws {
        let value = try PureYAML.parse("mode: legacy")
        let validator = PureYAML.Validation.Validator.blank.validating(legacyModeRule(severity: .warning))

        expectValidationError(value, using: validator) { collection in
            #expect(collection.issues.map(\.severity) == [.warning])
        }
    }

    @Test("Non-strict validation returns warnings")
    func test_nonStrictValidationReturnsWarnings() throws {
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
    func test_validationResultSeparatesErrorsAndWarnings() {
        let result = PureYAML.Validation.Result([
            .init(severity: .error, reason: "error"),
            .init(severity: .warning, reason: "warning"),
        ])

        #expect(result.isValid == false)
        #expect(result.errors.map(\.reason) == ["error"])
        #expect(result.warnings.map(\.reason) == ["warning"])
    }

    @Test("Validation paths describe roots, keys, and indexes")
    func test_validationPathsDescribeRootsKeysAndIndexes() {
        let path = PureYAML.Validation.Path.root
            .appending(.key("routes"))
            .appending(.index(1))
            .appending(.key("name"))

        #expect(PureYAML.Validation.Path.root.description == "$")
        #expect(PureYAML.Validation.Path.root.isRoot)
        #expect(path.description == "$.routes[1].name")
    }

    @Test("Validation issue descriptions include severity reason and path")
    func test_validationIssueDescriptionsIncludeSeverityReasonAndPath() {
        let issue = PureYAML.Validation.Issue(
            severity: .error,
            reason: "Duplicate mapping key 'title'",
            path: .init([.key("title")]),
        )

        #expect(issue.description == "error: Duplicate mapping key 'title' at $.title")
    }

    @Test("Validation issue collection describes all failures")
    func test_validationIssueCollectionDescription() {
        let collection = PureYAML.Validation.Issue.Collection([
            .init(severity: .error, reason: "first", path: .root),
            .init(severity: .warning, reason: "second", path: .init([.key("name")])),
        ])

        #expect(collection.description == """
        error: first at root
        warning: second at $.name
        """)
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

private func expectValidationError(
    _ value: PureYAML.Model.Value,
    using validator: PureYAML.Validation.Validator = .init(),
    check: (PureYAML.Validation.Issue.Collection) -> Void,
) {
    do {
        try PureYAML.validate(value, using: validator)
        recordIssue("expected validation failure")
    } catch let collection as PureYAML.Validation.Issue.Collection {
        check(collection)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}
