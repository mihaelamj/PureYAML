@testable import PureYAML
import Testing

@Suite("Parsing Compatibility")
struct ParsingCompatibilityTests {
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
}
