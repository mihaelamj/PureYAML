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

    @Test("Pins merge keys as unsupported unflattened mappings")
    func test_mergeKeysRemainUnflattenedUntilExplicitlySupported() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            defaults: &defaults {enabled: true, retries: 3}
            service:
              <<: *defaults
              name: API
            """,
        ))

        guard
            case let .mapping(service)? = root?["service"],
            case let .mapping(mergedDefaults)? = service["<<"]
        else {
            recordIssue("expected unflattened merge-key mapping")
            return
        }

        #expect(mergedDefaults["enabled"] == .bool(true))
        #expect(mergedDefaults["retries"] == .int(3))
        #expect(service["name"] == .string("API"))
        #expect(service["enabled"] == nil)
        #expect(service["retries"] == nil)
        #expect(root?["enabled"] == nil)
        #expect(root?["missing"] == nil)
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
