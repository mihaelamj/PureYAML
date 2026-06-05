@testable import PureYAML
import Testing

@Suite("Complex Mapping Key Dumper")
struct ComplexMappingKeyDumperTests {
    @Test("Dumps block complex keys with deterministic explicit key syntax")
    func test_dumpsBlockComplexKeysWithDeterministicExplicitKeySyntax() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(
                keyNode: .sequence([.string("Detroit Tigers"), .string("Chicago Cubs")]),
                value: .sequence([.string("2001-07-23")]),
            ),
            .init(
                keyNode: .mapping(.init([
                    .init(key: "name", value: .string("Example")),
                ])),
                value: .string("active"),
            ),
        ]))
        let yaml = PureYAML.dump(value)

        #expect(yaml == """
        ? ["Detroit Tigers", "Chicago Cubs"]
        :
          - "2001-07-23"
        ? {"name": "Example"}
        :
          "active"

        """)
        #expect(!yaml.contains("? [Detroit Tigers"))
        #expect(try PureYAML.parse(yaml) == value)
    }

    @Test("Dumps flow complex keys with deterministic explicit key syntax")
    func test_dumpsFlowComplexKeysWithDeterministicExplicitKeySyntax() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(
                keyNode: .sequence([.string("a"), .string("b")]),
                value: .mapping(.init([
                    .init(key: "mode", value: .string("active")),
                ])),
            ),
        ]))
        let options = PureYAML.Emitting.Options(collectionStyle: .flow)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        {? ["a", "b"]: {"mode": "active"}}

        """)
        #expect(!yaml.contains("\n  -"))
        #expect(try PureYAML.parse(yaml) == value)
    }
}
