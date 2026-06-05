@testable import PureYAML
import Testing

@Suite("Parsing Compatibility")
struct ParsingCompatibilityTests {
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
}
