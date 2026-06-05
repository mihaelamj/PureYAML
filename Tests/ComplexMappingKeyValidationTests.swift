@testable import PureYAML
import Testing

@Suite("Complex Mapping Key Validation")
struct ComplexMappingKeyValidationTests {
    @Test("Validates duplicate complex keys with exact diagnostics")
    func test_validatesDuplicateComplexKeysWithExactDiagnostics() {
        let key = PureYAML.Model.Key.sequence([.string("a"), .string("b")])
        let value = PureYAML.Model.Value.mapping(.init([
            .init(keyNode: key, value: .string("first")),
            .init(keyNode: key, value: .string("second")),
        ]))
        let expectedIssue = PureYAML.Validation.Issue(
            severity: .error,
            reason: "Duplicate mapping key '[\"a\", \"b\"]'",
            path: .init([.complexKey(key)]),
        )

        let result = PureYAML.Validation.Validator().collect(value)

        #expect(result.issues == [expectedIssue])
        #expect(result.issues.map(\.description) == [
            "error: Duplicate mapping key '[\"a\", \"b\"]' at $[?[\"a\", \"b\"]]",
        ])
        expectValidationError(value) { collection in
            #expect(collection.issues == [expectedIssue])
            #expect(collection.description == expectedIssue.description)
        }
    }

    @Test("Validates duplicate complex mapping keys with exact diagnostics")
    func test_validatesDuplicateComplexMappingKeysWithExactDiagnostics() {
        let key = PureYAML.Model.Key.mapping(.init([
            .init(key: "name", value: .string("service")),
        ]))
        let value = PureYAML.Model.Value.mapping(.init([
            .init(keyNode: key, value: .string("first")),
            .init(keyNode: key, value: .string("second")),
        ]))
        let expectedIssue = PureYAML.Validation.Issue(
            severity: .error,
            reason: "Duplicate mapping key '{\"name\": \"service\"}'",
            path: .init([.complexKey(key)]),
        )

        expectValidationError(value) { collection in
            #expect(collection.issues == [expectedIssue])
            #expect(collection.description == """
            error: Duplicate mapping key '{"name": "service"}' at $[?{"name": "service"}]
            """)
        }
    }

    @Test("Validates duplicate complex keys containing NaN deterministically")
    func test_validatesDuplicateComplexKeysContainingNanDeterministically() {
        let key = PureYAML.Model.Key.sequence([.double(.nan)])
        let value = PureYAML.Model.Value.mapping(.init([
            .init(keyNode: key, value: .string("first")),
            .init(keyNode: key, value: .string("second")),
        ]))
        let expectedIssue = PureYAML.Validation.Issue(
            severity: .error,
            reason: "Duplicate mapping key '[nan]'",
            path: .init([.complexKey(key)]),
        )

        #expect(PureYAML.Model.Value.double(.nan) == .double(.nan))
        expectValidationError(value) { collection in
            #expect(collection.issues == [expectedIssue])
            #expect(collection.description == "error: Duplicate mapping key '[nan]' at $[?[nan]]")
        }
    }

    @Test("Does not collapse scalar strings and complex keys that render alike")
    func test_doesNotCollapseScalarStringsAndComplexKeysThatRenderAlike() throws {
        let sequenceKey = PureYAML.Model.Key.sequence([.string("a")])
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "[\"a\"]", value: .string("scalar")),
            .init(keyNode: sequenceKey, value: .string("complex")),
        ]))

        let issues = try PureYAML.validate(value, strict: false)

        #expect(issues.isEmpty)
        #expect(PureYAML.Validation.Validator().collect(value).issues.isEmpty)
        #expect(value.rootMapping?["[\"a\"]"] == .string("scalar"))
        #expect(value.rootMapping?[sequenceKey] == .string("complex"))
        #expect(value.rootMapping?["a"] == nil)
    }

    @Test("Traverses values under complex keys with exact paths")
    func test_traversesValuesUnderComplexKeysWithExactPaths() {
        let key = PureYAML.Model.Key.mapping(.init([
            .init(key: "name", value: .string("service")),
        ]))
        let value = PureYAML.Model.Value.mapping(.init([
            .init(keyNode: key, value: .mapping(.init([
                .init(key: "mode", value: .string("legacy")),
            ]))),
        ]))
        let expectedIssue = PureYAML.Validation.Issue(
            severity: .error,
            reason: "Legacy mode is not allowed",
            path: .init([.complexKey(key), .key("mode")]),
        )

        let result = PureYAML.Validation.Validator.blank
            .validating(legacyModeRule(severity: .error))
            .collect(value)

        #expect(result.issues == [expectedIssue])
        #expect(result.issues.first?.description == """
        error: Legacy mode is not allowed at $[?{"name": "service"}].mode
        """)
    }
}
