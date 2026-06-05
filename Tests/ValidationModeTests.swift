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

    @Test("Validation rule predicate prevents rule from running")
    func test_validationRulePredicatePreventsRuleFromRunning() throws {
        let value = try PureYAML.parse("mode: legacy")
        let validator = PureYAML.Validation.Validator.blank.validating(
            PureYAML.Validation.Rule(
                description: "Never runs",
                check: { context in
                    [
                        PureYAML.Validation.Issue(
                            severity: .error,
                            reason: "Should not appear",
                            path: context.path,
                        ),
                    ]
                },
                when: { _ in false },
            ),
        )

        let result = validator.collect(value)

        #expect(result == PureYAML.Validation.Result())
        #expect(result.isValid)
    }

    @Test("Validation rule predicate filters applied subjects")
    func test_validationRulePredicateFiltersAppliedSubjects() throws {
        let value = try PureYAML.parse(
            """
            mode: modern
            nested:
              mode: legacy
              label: legacy
            """,
        )
        let validator = PureYAML.Validation.Validator.blank.validating(
            PureYAML.Validation.Rule(
                description: "Legacy mode is not allowed",
                check: { context in
                    [
                        PureYAML.Validation.Issue(
                            severity: .error,
                            reason: "Legacy mode is not allowed",
                            path: context.path,
                        ),
                    ]
                },
                when: { context in
                    context.path.components.last == .key("mode")
                        && context.subject == .string("legacy")
                },
            ),
        )

        let result = validator.collect(value)

        #expect(result.issues == [
            .init(
                severity: .error,
                reason: "Legacy mode is not allowed",
                path: .init([.key("nested"), .key("mode")]),
            ),
        ])
        #expect(!result.issues.contains(.init(
            severity: .error,
            reason: "Legacy mode is not allowed",
            path: .init([.key("nested"), .key("label")]),
        )))
    }

    @Test("Validation rules can inspect root subject and path deterministically")
    func test_validationRulesCanInspectRootSubjectAndPathDeterministically() throws {
        let value = try PureYAML.parse(
            """
            required_prefix: prod
            routes:
              - name: prod-users
              - name: test-status
              - label: test-ignored
            """,
        )
        let validator = PureYAML.Validation.Validator.blank.validating(
            PureYAML.Validation.Rule(
                description: "Route names use the root prefix",
                check: { context in
                    guard case let .mapping(root) = context.root,
                          case let .string(prefix)? = root["required_prefix"],
                          case let .string(name) = context.subject,
                          name.hasPrefix("\(prefix)-")
                    else {
                        return [
                            PureYAML.Validation.Issue(
                                severity: .error,
                                reason: "Route name does not use root prefix",
                                path: context.path,
                            ),
                        ]
                    }
                    return []
                },
                when: { context in
                    context.path.components.last == .key("name")
                },
            ),
        )

        let result = validator.collect(value)

        #expect(result.issues == [
            .init(
                severity: .error,
                reason: "Route name does not use root prefix",
                path: .init([.key("routes"), .index(1), .key("name")]),
            ),
        ])
        #expect(!result.issues.contains(.init(
            severity: .error,
            reason: "Route name does not use root prefix",
            path: .init([.key("routes"), .index(2), .key("label")]),
        )))
    }

    @Test("Boolean validation rule reports exact default failure reason")
    func test_booleanValidationRuleReportsExactDefaultFailureReason() throws {
        let value = try PureYAML.parse(
            """
            title: Example
            state: draft
            """,
        )
        let validator = PureYAML.Validation.Validator.blank.validating(
            PureYAML.Validation.Rule(
                description: "State is published",
                check: { context in context.subject == .string("published") },
                when: { context in context.path.components.last == .key("state") },
            ),
        )

        expectValidationError(value, using: validator) { collection in
            #expect(collection.issues == [
                .init(
                    severity: .error,
                    reason: "Failed to satisfy: State is published",
                    path: .init([.key("state")]),
                ),
            ])
        }

        let valid = try PureYAML.parse("state: published")
        #expect(try PureYAML.validate(valid, using: validator).isEmpty)
    }
}
