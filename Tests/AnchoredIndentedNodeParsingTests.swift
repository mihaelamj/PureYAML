@testable import PureYAML
import Testing

@Suite("Anchored Indented Node Parsing")
struct AnchoredIndentedNodeParsingTests {
    @Test("Resolves anchors on indented mapping and sequence nodes")
    func test_anchorsOnIndentedMappingAndSequenceNodes() throws {
        let value = try PureYAML.parse(
            """
            mapping: &mapping
              name: Example
            sequence:
              - &item
                title: First
              - *item
            alias: *mapping
            """,
        )

        let root = requireMapping(value)
        #expect(root?["mapping"] == root?["alias"])
        guard
            case let .sequence(values)? = root?["sequence"],
            values.count == 2,
            case let .mapping(first) = values[0],
            case let .mapping(second) = values[1]
        else {
            recordIssue("expected anchored sequence item mapping")
            return
        }
        #expect(first["title"] == .string("First"))
        #expect(second["title"] == .string("First"))
        #expect(values[0] == values[1])
    }
}
