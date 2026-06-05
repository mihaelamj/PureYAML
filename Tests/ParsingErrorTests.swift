@testable import PureYAML
import Testing

@Suite("Parsing Errors")
struct ParsingErrorTests {
    @Test("Reports exact parser errors")
    func test_errorReporting() {
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
        expectParseError("%YAML 1.3\n---\nvalue: yes", .incompatibleYAMLDirective(line: 1))
        expectParseError("value: !!int nope", .invalidTaggedScalar(
            tag: "tag:yaml.org,2002:int",
            value: "nope",
            line: 1,
            column: 8,
        ))
    }

    @Test("Parses empty and comment-only documents as null")
    func test_emptyAndCommentOnlyDocumentsParseAsNull() throws {
        #expect(try PureYAML.parse("") == .null)
        #expect(try PureYAML.parse("# comment only") == .null)
        #expect(try PureYAML.parse("   \n# comment only\n") == .null)
    }

    @Test("Parses tab indentation with permissive tab stops")
    func test_tabIndentationUsesPermissiveTabStops() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            root:
            \tchild: value
            """,
        ))

        #expect(root?.mapping("root")?["child"] == .string("value"))
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
        #expect(PureYAML.Parsing.ParseError.incompatibleYAMLDirective(line: 10).description == "incompatible YAML directive at line 10")
        #expect(PureYAML.Parsing.ParseError.unsupportedDirective(name: "%FOO", line: 10).description == "unsupported directive '%FOO' at line 10")
        #expect(PureYAML.Parsing.ParseError.unsupportedMultiDocumentStream(line: 10).description == "multi-document streams are not supported at line 10")
        #expect(PureYAML.Parsing.ParseError.expectedNode(line: 10, column: 2).description == "expected a YAML node at line 10, column 2")
        #expect(PureYAML.Parsing.ParseError.expectedScalarKey(line: 11, column: 3).description == "expected a scalar mapping key at line 11, column 3")
        #expect(PureYAML.Parsing.ParseError.undefinedAlias(anchor: "item", line: 12, column: 4).description == "undefined alias 'item' at line 12, column 4")
        #expect(PureYAML.Parsing.ParseError.invalidTaggedScalar(
            tag: "tag:yaml.org,2002:int",
            value: "nope",
            line: 13,
            column: 5,
        ).description == "invalid scalar 'nope' for tag 'tag:yaml.org,2002:int' at line 13, column 5")
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
