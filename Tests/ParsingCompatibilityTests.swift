@testable import PureYAML
import Testing

@Suite("Parsing Compatibility")
struct ParsingCompatibilityTests {
    @Test(
        "Parses fixture-backed block flow and anchor collections",
        arguments: CollectionCompatibilityFixtures.supportedCollections,
    )
    func test_collectionCompatibilityFixtures(testCase: CollectionCompatibilityFixtures.SuccessCase) throws {
        let value = try PureYAML.parse(testCase.yaml)

        #expect(value == testCase.expected)
        expectAbsentRootKeys(testCase.absentRootKeys, in: value)
        #expect(PureYAML.Validation.Validator().collect(value) == PureYAML.Validation.Result())
    }

    @Test(
        "Reports exact collection parse errors",
        arguments: CollectionCompatibilityFixtures.parseErrors,
    )
    func test_collectionParseErrors(testCase: CollectionCompatibilityFixtures.ParseErrorCase) {
        expectParseError(testCase.yaml, testCase.expected)
        #expect(testCase.expected.description == testCase.expectedDescription)
    }

    @Test(
        "Validates collection duplicate keys exactly",
        arguments: CollectionCompatibilityFixtures.duplicateKeyValidation,
    )
    func test_collectionDuplicateKeyValidation(testCase: CollectionCompatibilityFixtures.ValidationCase) throws {
        let value = try PureYAML.parse(testCase.yaml)
        let result = PureYAML.Validation.Validator().collect(value)

        #expect(result.issues == testCase.expectedIssues)
        #expect(result.errors == testCase.expectedIssues)
        #expect(result.warnings.isEmpty)
        expectValidationError(value) { collection in
            #expect(collection.issues == testCase.expectedIssues)
            #expect(collection.description == testCase.expectedIssues.map(\.description).joined(separator: "\n"))
        }
    }

    @Test(
        "Reports exact unsupported YAML gap errors",
        arguments: UnsupportedYAMLGapsFixtures.parseErrors,
    )
    func test_unsupportedYAMLGapParseErrors(testCase: UnsupportedYAMLGapsFixtures.ParseErrorCase) {
        expectParseError(testCase.yaml, testCase.expected)
        #expect(testCase.expected.description == testCase.expectedDescription)
    }

    @Test(
        "Keeps unsupported YAML gaps as exact fallback values",
        arguments: UnsupportedYAMLGapsFixtures.fallbackValues,
    )
    func test_unsupportedYAMLGapFallbackValues(testCase: UnsupportedYAMLGapsFixtures.FallbackValueCase) throws {
        let value = try PureYAML.parse(testCase.yaml)

        #expect(value == testCase.expected)
        expectAbsentRootKeys(testCase.absentRootKeys, in: value)
        #expect(PureYAML.Validation.Validator().collect(value) == PureYAML.Validation.Result())
    }

    @Test("Validates direct values for gaps ordinary loaders may collapse")
    func test_directUnsupportedGapValueValidation() {
        let value = UnsupportedYAMLGapsFixtures.directPreservedValue
        let result = PureYAML.Validation.Validator().collect(value)

        guard case let .mapping(mapping) = value else {
            recordIssue("expected direct mapping value")
            return
        }

        #expect(mapping.pairs.map(\.key) == ["<<", "title", "title"])
        #expect(mapping["<<"] == .mapping(.init([
            .init(key: "enabled", value: .bool(true)),
        ])))
        #expect(result.issues == UnsupportedYAMLGapsFixtures.directPreservedIssues)
        #expect(result.issues.map(\.description) == [
            "error: Duplicate mapping key 'title' at $.title",
        ])
        expectValidationError(value) { collection in
            #expect(collection.issues == UnsupportedYAMLGapsFixtures.directPreservedIssues)
            #expect(collection.description == "error: Duplicate mapping key 'title' at $.title")
        }
    }

    @Test("Expands merge keys while keeping source mappings visible")
    func test_mergeKeysExpandIntoEffectiveMappings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            defaults: &defaults {enabled: true, retries: 3}
            service:
              <<: *defaults
              name: API
            """,
        ))

        guard case let .mapping(service)? = root?["service"] else {
            recordIssue("expected merged service mapping")
            return
        }

        #expect(service.pairs.map(\.key) == ["enabled", "retries", "name"])
        #expect(service["enabled"] == .bool(true))
        #expect(service["retries"] == .int(3))
        #expect(service["name"] == .string("API"))
        #expect(service["<<"] == nil)
        #expect(root?["defaults"] != nil)
        #expect(root?["enabled"] == nil)
        #expect(root?["missing"] == nil)
    }

    @Test("Parses JSON-style compact flow mappings")
    func test_jsonStyleCompactFlowMappings() throws {
        let root = try requireMapping(PureYAML.parse(
            #"{"openapi":"3.0.0","info":{"title":"JSON API","version":"1"},"paths":{},"enabled":true,"count":3}"#,
        ))

        #expect(root?["openapi"] == .string("3.0.0"))
        #expect(root?.mapping("info")?["title"] == .string("JSON API"))
        #expect(root?.mapping("info")?["version"] == .string("1"))
        #expect(root?["paths"] == .mapping(.init()))
        #expect(root?["enabled"] == .bool(true))
        #expect(root?["count"] == .int(3))
    }

    @Test("Keeps colons inside JSON-style flow mapping values")
    func test_jsonStyleFlowMappingValuesCanContainColons() throws {
        let root = try requireMapping(PureYAML.parse(
            #"{"url":"https://api.example.com/v1","window":"10:30","items":["a:b","c"]}"#,
        ))

        #expect(root?["url"] == .string("https://api.example.com/v1"))
        #expect(root?["window"] == .string("10:30"))
        #expect(root?["items"] == .sequence([.string("a:b"), .string("c")]))
    }

    @Test(
        "Resolves selected Yams-compatible scalar spellings",
        arguments: ScalarCompatibilityFixtures.resolvedScalars,
    )
    func test_selectedScalarResolution(testCase: ScalarCompatibilityFixtures.SuccessCase) throws {
        let root = try requireMapping(PureYAML.parse(testCase.yaml))

        expectScalar(root?["value"], testCase.expected)
        #expect(root?["missing"] == nil)
        if let forbiddenString = testCase.forbiddenString {
            #expect(root?["value"] != .string(forbiddenString))
        }
    }

    @Test(
        "Applies explicit built-in scalar tags",
        arguments: ScalarCompatibilityFixtures.explicitScalarTags,
    )
    func test_explicitBuiltInScalarTags(testCase: ScalarCompatibilityFixtures.SuccessCase) throws {
        let root = try requireMapping(PureYAML.parse(testCase.yaml))

        expectScalar(root?["value"], testCase.expected)
        #expect(root?["missing"] == nil)
        if let forbiddenString = testCase.forbiddenString {
            #expect(root?["value"] != .string(forbiddenString))
        }
    }

    @Test(
        "Keeps explicit and quoted strings from resolving",
        arguments: ScalarCompatibilityFixtures.stringScalars,
    )
    func test_stringScalarsDoNotResolve(testCase: ScalarCompatibilityFixtures.SuccessCase) throws {
        let root = try requireMapping(PureYAML.parse(testCase.yaml))

        expectScalar(root?["value"], testCase.expected)
        #expect(root?["value"] != .bool(true))
        #expect(root?["value"] != .bool(false))
        #expect(root?["missing"] == nil)
    }

    @Test(
        "Pins unsupported scalar spellings as strings",
        arguments: ScalarCompatibilityFixtures.unsupportedScalars,
    )
    func test_unsupportedScalarSpellingsStayStrings(testCase: ScalarCompatibilityFixtures.SuccessCase) throws {
        let root = try requireMapping(PureYAML.parse(testCase.yaml))

        expectScalar(root?["value"], testCase.expected)
        #expect(root?["value"] != .null)
        #expect(root?["missing"] == nil)
    }

    @Test(
        "Reports exact invalid explicit scalar tag errors",
        arguments: ScalarCompatibilityFixtures.invalidExplicitScalarTags,
    )
    func test_invalidExplicitScalarTags(testCase: ScalarCompatibilityFixtures.ErrorCase) {
        expectParseError(testCase.yaml, testCase.expected)
    }

    @Test("Parses directives document markers and explicit scalar tags")
    func test_directivesDocumentMarkersAndExplicitScalarTags() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            %YAML 1.2
            %TAG !yaml! tag:yaml.org,2002:
            ---
            forced: !yaml!str true
            number: !!int "42"
            ratio: !<tag:yaml.org,2002:float> "3.5"
            enabled: !!bool "false"
            missing: !!null ignored
            custom: !<tag:example.com,2026:thing> true
            ...
            """,
        ))

        #expect(root?["forced"] == .string("true"))
        #expect(root?["number"] == .int(42))
        #expect(root?["ratio"] == .double(3.5))
        #expect(root?["enabled"] == .bool(false))
        #expect(root?["missing"] == .null)
        #expect(root?["custom"] == .bool(true))
    }

    private func expectScalar(
        _ value: PureYAML.Model.Value?,
        _ expected: ScalarCompatibilityFixtures.Expected,
    ) {
        switch expected {
        case .null:
            #expect(value == .null)
        case let .bool(expected):
            #expect(value == .bool(expected))
        case let .int(expected):
            #expect(value == .int(expected))
        case let .double(expected):
            guard case let .double(actual)? = value else {
                recordIssue("expected double \(expected), got \(String(describing: value))")
                return
            }
            #expect(actual == expected)
        case .nan:
            guard case let .double(actual)? = value else {
                recordIssue("expected NaN double, got \(String(describing: value))")
                return
            }
            #expect(actual.isNaN)
        case let .string(expected):
            #expect(value == .string(expected))
        }
    }

    private func expectAbsentRootKeys(
        _ keys: [String],
        in value: PureYAML.Model.Value,
    ) {
        guard !keys.isEmpty else {
            return
        }
        guard case let .mapping(mapping) = value else {
            recordIssue("expected root mapping for absence checks")
            return
        }
        for key in keys {
            #expect(mapping[key] == nil)
        }
    }
}
