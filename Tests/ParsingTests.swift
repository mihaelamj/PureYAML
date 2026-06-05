@testable import PureYAML
import Testing

@Suite("Parsing")
struct ParsingTests {
    struct ScalarCase {
        var yaml: String
        var expected: PureYAML.Model.Value
    }

    @Test("Parses block mappings with common scalars")
    func test_blockMappingWithCommonScalars() throws {
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
        #expect(root?["unknown"] == nil)
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
    func test_scalarSpellings(testCase: ScalarCase) throws {
        let root = try requireMapping(PureYAML.parse(testCase.yaml))

        #expect(root?["value"] == testCase.expected)
    }

    @Test("Parses quoted strings and escapes")
    func test_quotedStringsAndEscapes() throws {
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
    func test_commentsOutsideQuotedStrings() throws {
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
        #expect(root?["plain"] != .string("value"))
    }

    @Test("Parses nested mappings and sequences")
    func test_nestedMappingsAndSequences() throws {
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
    func test_sequenceOfMappings() throws {
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
    func test_topLevelSequences() throws {
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

    @Test("Parses flow collections through the event composer")
    func test_flowCollections() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            values: [one, 2, false, {name: Example}]
            """,
        ))

        guard
            let values = requireSequence(root?["values"]),
            values.count == 4,
            case let .mapping(mapping) = values[3]
        else {
            recordIssue("expected flow collection values")
            return
        }
        #expect(values[0] == .string("one"))
        #expect(values[1] == .int(2))
        #expect(values[2] == .bool(false))
        #expect(mapping["name"] == .string("Example"))
    }

    @Test("Parses block scalars through the event composer")
    func test_blockScalars() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            text: |
              one
              two
            folded: >
              one
              two
            """,
        ))

        #expect(root?["text"] == .string("one\ntwo\n"))
        #expect(root?["folded"] == .string("one two\n"))
    }

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

    @Test("Reports exact parser errors")
    func test_errorReporting() {
        expectParseError("", .emptyDocument)
        expectParseError("# comment only", .emptyDocument)
        expectParseError("\tkey: value", .tabIndentation(line: 1))
        expectParseError("root:\n    child: yes\n  wrong: no", .unexpectedIndentation(line: 3))
        expectParseError("- one\nkey: value", .mixedCollectionStyles(line: 2))
        expectParseError("root:\n  child: value\n  dangling", .unexpectedToken(
            expected: "mapping key",
            actual: "scalar value=\"dangling\" style=plain",
            line: 3,
            column: 3,
        ))
        expectParseError("name: \"open", .unterminatedQuotedString(line: 1))
        expectParseError("name: 'open", .unterminatedQuotedString(line: 1))
        expectParseError("second: *missing", .undefinedAlias(anchor: "missing", line: 1, column: 9))
    }

    @Test("Parser errors describe returned failures")
    func test_errorDescriptions() {
        #expect(PureYAML.Parsing.ParseError.emptyDocument.description == "document is empty")
        #expect(PureYAML.Parsing.ParseError.tabIndentation(line: 2).description == "tabs are not allowed for indentation at line 2")
        #expect(PureYAML.Parsing.ParseError.unexpectedIndentation(line: 3).description == "unexpected indentation at line 3")
        #expect(PureYAML.Parsing.ParseError.mixedCollectionStyles(line: 4).description == "mapping and sequence entries are mixed at line 4")
        #expect(PureYAML.Parsing.ParseError.expectedMappingKey(line: 5).description == "expected a mapping key at line 5")
        #expect(PureYAML.Parsing.ParseError.expectedAnchorName(line: 6).description == "expected an anchor name at line 6")
        #expect(PureYAML.Parsing.ParseError.expectedAliasName(line: 7).description == "expected an alias name at line 7")
        #expect(PureYAML.Parsing.ParseError.unterminatedTag(line: 8).description == "unterminated tag at line 8")
        #expect(PureYAML.Parsing.ParseError.unterminatedQuotedString(line: 9).description == "unterminated quoted string at line 9")
        #expect(PureYAML.Parsing.ParseError.expectedNode(line: 10, column: 2).description == "expected a YAML node at line 10, column 2")
        #expect(PureYAML.Parsing.ParseError.expectedScalarKey(line: 11, column: 3).description == "expected a scalar mapping key at line 11, column 3")
        #expect(PureYAML.Parsing.ParseError.undefinedAlias(anchor: "item", line: 12, column: 4).description == "undefined alias 'item' at line 12, column 4")
        #expect(PureYAML.Parsing.ParseError.unexpectedEvent(
            expected: "mapping key",
            actual: "sequenceStart anchor=- tag=- style=flow @1:1@0",
            line: 13,
            column: 5,
        ).description == "expected mapping key at line 13, column 5, found sequenceStart anchor=- tag=- style=flow @1:1@0")
        #expect(PureYAML.Parsing.ParseError.unexpectedToken(
            expected: "stream end",
            actual: "mappingKey",
            line: 14,
            column: 1,
        ).description == "expected stream end at line 14, column 1, found mappingKey")
    }
}
