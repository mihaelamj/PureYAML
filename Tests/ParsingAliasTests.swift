@testable import PureYAML
import Testing

@Suite("Parsing Aliases")
struct ParsingAliasTests {
    @Test("Resolves anchors and aliases through the event composer")
    func test_anchorsAndAliases() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            first: &item {name: Example}
            second: *item
            """,
        ))

        #expect(root?["first"] == root?["second"])
        guard case let .mapping(second)? = root?["second"] else {
            recordIssue("expected aliased mapping")
            return
        }
        #expect(second["name"] == .string("Example"))
    }
}
