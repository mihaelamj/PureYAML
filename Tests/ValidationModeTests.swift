@testable import PureYAML
import Testing

@Suite("Validation Modes")
struct ValidationModeTests {
    @Test("Custom validation rules report exact errors")
    func test_customValidationRuleErrors() throws {
        let value = try PureYAML.parse(
            """
            mode: legacy
            nested:
              mode: legacy
            """,
        )
        let validator = PureYAML.Validation.Validator.blank.validating(legacyModeRule(severity: .error))

        expectValidationError(value, using: validator) { collection in
            #expect(collection.issues == [
                .init(
                    severity: .error,
                    reason: "Legacy mode is not allowed",
                    path: .init([.key("mode")]),
                ),
                .init(
                    severity: .error,
                    reason: "Legacy mode is not allowed",
                    path: .init([.key("nested"), .key("mode")]),
                ),
            ])
        }
    }

    @Test("Strict validation treats warnings as failures")
    func test_strictValidationTreatsWarningsAsFailures() throws {
        let value = try PureYAML.parse("mode: legacy")
        let validator = PureYAML.Validation.Validator.blank.validating(legacyModeRule(severity: .warning))

        expectValidationError(value, using: validator) { collection in
            #expect(collection.issues == [
                .init(
                    severity: .warning,
                    reason: "Legacy mode is not allowed",
                    path: .init([.key("mode")]),
                ),
            ])
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

    @Test("Non-strict validation throws only errors when errors and warnings are mixed")
    func test_nonStrictValidationThrowsOnlyErrorsWhenErrorsAndWarningsAreMixed() throws {
        let value = try PureYAML.parse(
            """
            title: First
            title: Second
            mode: legacy
            """,
        )
        let validator = PureYAML.Validation.Validator()
            .validating(legacyModeRule(severity: .warning))

        expectValidationError(value, using: validator, strict: false) { collection in
            #expect(collection.issues == [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
            ])
            #expect(!collection.issues.contains(.init(
                severity: .warning,
                reason: "Legacy mode is not allowed",
                path: .init([.key("mode")]),
            )))
        }
    }

    @Test("Validation traversal preserves rule order before child paths")
    func test_validationTraversalPreservesRuleOrderBeforeChildPaths() throws {
        let value = try PureYAML.parse(
            """
            root:
              mode: legacy
            list:
              - mode: legacy
            """,
        )
        let validator = PureYAML.Validation.Validator.blank
            .validating(traceRule(label: "first"))
            .validating(traceRule(label: "second"))
            .validating(legacyModeRule(severity: .warning))

        let result = validator.collect(value)

        #expect(result.issues.map(\.description) == [
            "warning: first at root at root",
            "warning: second at root at root",
            "warning: first at $.root at $.root",
            "warning: second at $.root at $.root",
            "warning: first at $.root.mode at $.root.mode",
            "warning: second at $.root.mode at $.root.mode",
            "warning: Legacy mode is not allowed at $.root.mode",
            "warning: first at $.list at $.list",
            "warning: second at $.list at $.list",
            "warning: first at $.list[0] at $.list[0]",
            "warning: second at $.list[0] at $.list[0]",
            "warning: first at $.list[0].mode at $.list[0].mode",
            "warning: second at $.list[0].mode at $.list[0].mode",
            "warning: Legacy mode is not allowed at $.list[0].mode",
        ])
    }
}
