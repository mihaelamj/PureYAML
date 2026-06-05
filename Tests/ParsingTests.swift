@testable import PureYAML
import Testing

@Suite("Parsing")
struct ParsingTests {
    struct ScalarCase {
        var yaml: String
        var expected: PureYAML.Model.Value
    }

    @Test("Parses block mappings with common scalars")
    func parsesBlockMappingWithCommonScalars() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            openapi: 3.1.0
            title: "Example API"
            active: true
            retries: 3
            ratio: 3.1
            missing: null
            """,
        ))

        #expect(root?["openapi"] == .string("3.1.0"))
        #expect(root?["title"] == .string("Example API"))
        #expect(root?["active"] == .bool(true))
        #expect(root?["retries"] == .int(3))
        #expect(root?["ratio"] == .double(3.1))
        #expect(root?["missing"] == .null)
    }

    @Test("Parses scalar spellings", arguments: [
        ScalarCase(yaml: "value:", expected: .null),
        ScalarCase(yaml: "value: ~", expected: .null),
        ScalarCase(yaml: "value: NULL", expected: .null),
        ScalarCase(yaml: "value: True", expected: .bool(true)),
        ScalarCase(yaml: "value: FALSE", expected: .bool(false)),
        ScalarCase(yaml: "value: -7", expected: .int(-7)),
        ScalarCase(yaml: "value: 1e3", expected: .double(1000)),
        ScalarCase(yaml: "value: plain text", expected: .string("plain text")),
    ])
    func parsesScalarSpellings(testCase: ScalarCase) throws {
        let root = try requireMapping(PureYAML.parse(testCase.yaml))

        #expect(root?["value"] == testCase.expected)
    }

    @Test("Parses quoted strings and escapes")
    func parsesQuotedStringsAndEscapes() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            double: "line\\nnext\\tend"
            single: 'it''s'
            slash: "a\\/b"
            """,
        ))

        #expect(root?["double"] == .string("line\nnext\tend"))
        #expect(root?["single"] == .string("it's"))
        #expect(root?["slash"] == .string("a/b"))
    }

    @Test("Ignores comments outside quoted strings")
    func ignoresCommentsOutsideQuotedStrings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            title: "Keep # inside" # remove outside
            single: 'Keep # inside' # remove outside
            plain: value#kept # remove outside
            """,
        ))

        #expect(root?["title"] == .string("Keep # inside"))
        #expect(root?["single"] == .string("Keep # inside"))
        #expect(root?["plain"] == .string("value#kept"))
    }

    @Test("Parses nested mappings and sequences")
    func parsesNestedMappingsAndSequences() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            paths:
              /users:
                get:
                  tags:
                    - Users
                    - Public
            """,
        ))

        guard
            case let .mapping(paths)? = root?["paths"],
            case let .mapping(users)? = paths["/users"],
            case let .mapping(get)? = users["get"],
            case let .sequence(tags)? = get["tags"]
        else {
            recordIssue("expected nested tags")
            return
        }
        #expect(tags == [.string("Users"), .string("Public")])
    }

    @Test("Parses sequences of mappings")
    func parsesSequenceOfMappings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            servers:
              - url: /
                description: Default
              - url: https://example.com
                description: Production
            """,
        ))

        guard
            let servers = requireSequence(root?["servers"]),
            servers.count == 2,
            case let .mapping(first) = servers[0],
            case let .mapping(second) = servers[1]
        else {
            recordIssue("expected server mappings")
            return
        }

        #expect(first["url"] == .string("/"))
        #expect(first["description"] == .string("Default"))
        #expect(second["url"] == .string("https://example.com"))
        #expect(second["description"] == .string("Production"))
    }

    @Test("Parses top-level sequences")
    func parsesTopLevelSequences() throws {
        let value = try PureYAML.parse(
            """
            - one
            - 2
            - false
            """,
        )

        #expect(value == .sequence([
            .string("one"),
            .int(2),
            .bool(false),
        ]))
    }

    @Test("Reports exact parser errors")
    func reportsExactParserErrors() {
        expectParseError("", .emptyDocument)
        expectParseError("# comment only", .emptyDocument)
        expectParseError("\tkey: value", .tabIndentation(line: 1))
        expectParseError("root:\n    child: yes\n  wrong: no", .unexpectedIndentation(line: 3))
        expectParseError("- one\nkey: value", .mixedCollectionStyles(line: 2))
        expectParseError("root:\n  child: value\n  dangling", .expectedMappingKey(line: 3))
        expectParseError("name: \"open", .unterminatedQuotedString(line: 1))
        expectParseError("name: 'open", .unterminatedQuotedString(line: 1))
    }
}
