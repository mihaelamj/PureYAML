@testable import PureYAML
import Testing

@Suite("Scanner")
struct ScannerTests {
    @Test("Scans comments indentation block entries and mapping keys")
    func test_commentsIndentationBlockEntriesAndMappingKeys() throws {
        let tokens = try scanKinds(
            """
            # leading
            root:
              - name: "one" # inline
                enabled: true
            """,
        )

        expectKinds(tokens, [
            "streamStart",
            "comment value=\"leading\"",
            "mappingKey",
            "scalar value=\"root\" style=plain",
            "mappingValue",
            "indent width=2",
            "blockEntry",
            "mappingKey",
            "scalar value=\"name\" style=plain",
            "mappingValue",
            "scalar value=\"one\" style=doubleQuoted",
            "comment value=\"inline\"",
            "indent width=4",
            "mappingKey",
            "scalar value=\"enabled\" style=plain",
            "mappingValue",
            "scalar value=\"true\" style=plain",
            "dedent width=2",
            "dedent width=0",
            "streamEnd",
        ])
        expectDoesNotContain(tokens, [
            "flowSequenceStart",
            "flowMappingStart",
            "tag value=!Thing",
        ])
    }

    @Test("Scans explicit mapping keys and lower-indent dedents")
    func test_explicitMappingKeysAndLowerIndentDedents() throws {
        let tokens = try scanKinds(
            """
            root:
              nested:
                value: yes
            ? explicit
            : answer
            """,
        )

        expectKinds(tokens, [
            "streamStart",
            "mappingKey",
            "scalar value=\"root\" style=plain",
            "mappingValue",
            "indent width=2",
            "mappingKey",
            "scalar value=\"nested\" style=plain",
            "mappingValue",
            "indent width=4",
            "mappingKey",
            "scalar value=\"value\" style=plain",
            "mappingValue",
            "scalar value=\"yes\" style=plain",
            "dedent width=2",
            "dedent width=0",
            "mappingKey",
            "scalar value=\"explicit\" style=plain",
            "mappingValue",
            "scalar value=\"answer\" style=plain",
            "streamEnd",
        ])
        expectContains(tokens, [
            "dedent width=2",
            "dedent width=0",
            "mappingKey",
            "mappingValue",
        ])
    }

    @Test("Scans flow delimiters quoted scalars anchors aliases tags and block scalar headers")
    func test_flowDelimitersQuotedScalarsAnchorsAliasesTagsAndBlockScalarHeaders() throws {
        let tokens = try scanKinds(
            """
            flow: [!Thing &item "value", *item, {tagged: !<tag:example.com,2026:thing> 'it''s'}]
            text: |+
              line
            folded: >-
              line
            """,
        )

        expectFlowAndBlockScalarKinds(tokens)
        expectFlowAndBlockScalarRequiredKinds(tokens)
        expectFlowAndBlockScalarForbiddenKinds(tokens)
    }

    @Test("Plain scalars keep non-indicator hash and colon characters")
    func test_plainScalarsKeepNonIndicatorHashAndColonCharacters() throws {
        let tokens = try scanKinds(
            """
            url: https://example.com/a:b
            fragment: value#kept # removed
            """,
        )

        expectKinds(tokens, [
            "streamStart",
            "mappingKey",
            "scalar value=\"url\" style=plain",
            "mappingValue",
            "scalar value=\"https://example.com/a:b\" style=plain",
            "mappingKey",
            "scalar value=\"fragment\" style=plain",
            "mappingValue",
            "scalar value=\"value#kept\" style=plain",
            "comment value=\"removed\"",
            "streamEnd",
        ])
        expectContains(tokens, [
            "scalar value=\"https://example.com/a:b\" style=plain",
            "scalar value=\"value#kept\" style=plain",
            "comment value=\"removed\"",
        ])
        expectDoesNotContain(tokens, [
            "scalar value=\"https\" style=plain",
            "comment value=\"kept # removed\"",
        ])
    }

    @Test("Scans directives and document markers without value tokens")
    func test_directivesAndDocumentMarkers() throws {
        let tokens = try scanKinds(
            """
            %YAML 1.2
            %TAG !yaml! tag:yaml.org,2002:
            ---
            value: !yaml!str true
            ...
            """,
        )

        expectKinds(tokens, [
            "streamStart",
            "mappingKey",
            "scalar value=\"value\" style=plain",
            "mappingValue",
            "tag value=tag:yaml.org,2002:str",
            "scalar value=\"true\" style=plain",
            "streamEnd",
        ])
        expectDoesNotContain(tokens, [
            "scalar value=\"%YAML 1.2\" style=plain",
            "scalar value=\"---\" style=plain",
            "scalar value=\"...\" style=plain",
        ])
    }

    @Test("Tracks UTF-8 source marks")
    func test_utf8SourceMarks() throws {
        let tokens = try PureYAML.Parsing.Scanner().scan("caf\u{00E9}: yes")
        guard let key = tokens.first(where: {
            $0.kind == .scalar(value: "caf\u{00E9}", style: .plain)
        }) else {
            recordIssue("expected cafe scalar")
            return
        }
        guard let value = tokens.first(where: {
            $0.kind == .scalar(value: "yes", style: .plain)
        }) else {
            recordIssue("expected yes scalar")
            return
        }

        expectMarks(key, start: .init(line: 1, column: 1, index: 0), end: .init(line: 1, column: 5, index: 5))
        expectMarks(value, start: .init(line: 1, column: 7, index: 7), end: .init(line: 1, column: 10, index: 10))
    }

    @Test("Reader advances UTF-8 marks across line breaks")
    func test_readerAdvancesUTF8MarksAcrossLineBreaks() {
        var reader = PureYAML.Parsing.Reader("a\u{00E9}\n\u{03B2}\r\nz")

        expectReaderMark(&reader, line: 1, column: 1, index: 0)
        expectReaderMark(&reader, line: 1, column: 2, index: 1)
        expectReaderMark(&reader, line: 1, column: 3, index: 3)
        expectReaderMark(&reader, line: 2, column: 1, index: 4)
        expectReaderMark(&reader, line: 2, column: 2, index: 6)
        expectReaderMark(&reader, line: 3, column: 1, index: 8)
        expectReaderMark(&reader, line: 3, column: 2, index: 9, advanceAfterCheck: false)
    }

    @Test("Reports scanner errors")
    func test_errorReporting() {
        expectScannerError("\tname: value", .tabIndentation(line: 1))
        expectScannerError("root:\n    child: yes\n  wrong: no", .unexpectedIndentation(line: 3))
        expectScannerError("name: \"open", .unterminatedQuotedString(line: 1))
        expectScannerError("name: 'open", .unterminatedQuotedString(line: 1))
        expectScannerError("anchor: &", .expectedAnchorName(line: 1))
        expectScannerError("alias: *", .expectedAliasName(line: 1))
        expectScannerError("tag: !<tag:example.com,2026:thing", .unterminatedTag(line: 1))
        expectScannerError("%YAML 1.3\n---\nvalue: yes", .incompatibleYAMLDirective(line: 1))
    }
}

private func scanKinds(_ yaml: String) throws -> [String] {
    try PureYAML.Parsing.Scanner().scan(yaml).map(\.kind.description)
}

private func expectKinds(
    _ actual: [String],
    _ expected: [String],
) {
    #expect(actual == expected)
}

private func expectContains(
    _ actual: [String],
    _ required: [String],
) {
    for item in required {
        #expect(actual.contains(item))
    }
}

private func expectDoesNotContain(
    _ actual: [String],
    _ forbidden: [String],
) {
    for item in forbidden {
        #expect(!actual.contains(item))
    }
}

private func expectMarks(
    _ token: PureYAML.Parsing.Token,
    start: PureYAML.Parsing.Mark,
    end: PureYAML.Parsing.Mark,
) {
    #expect(token.mark == start)
    #expect(token.endMark == end)
}

private func expectFlowAndBlockScalarKinds(_ tokens: [String]) {
    expectKinds(tokens, [
        "streamStart",
        "mappingKey",
        "scalar value=\"flow\" style=plain",
        "mappingValue",
        "flowSequenceStart",
        "tag value=!Thing",
        "anchor name=item",
        "scalar value=\"value\" style=doubleQuoted",
        "flowEntry",
        "alias name=item",
        "flowEntry",
        "flowMappingStart",
        "mappingKey",
        "scalar value=\"tagged\" style=plain",
        "mappingValue",
        "tag value=!<tag:example.com,2026:thing>",
        "scalar value=\"it''s\" style=singleQuoted",
        "flowMappingEnd",
        "flowSequenceEnd",
        "mappingKey",
        "scalar value=\"text\" style=plain",
        "mappingValue",
        "blockScalarHeader style=literal",
        "indent width=2",
        "scalar value=\"line\" style=plain",
        "dedent width=0",
        "mappingKey",
        "scalar value=\"folded\" style=plain",
        "mappingValue",
        "blockScalarHeader style=folded",
        "indent width=2",
        "scalar value=\"line\" style=plain",
        "dedent width=0",
        "streamEnd",
    ])
}

private func expectFlowAndBlockScalarRequiredKinds(_ tokens: [String]) {
    expectContains(tokens, [
        "flowSequenceStart",
        "flowSequenceEnd",
        "flowMappingStart",
        "flowMappingEnd",
        "tag value=!Thing",
        "anchor name=item",
        "alias name=item",
        "blockScalarHeader style=literal",
        "blockScalarHeader style=folded",
    ])
}

private func expectFlowAndBlockScalarForbiddenKinds(_ tokens: [String]) {
    expectDoesNotContain(tokens, [
        "comment value=\"removed\"",
        "scalar value=\"tag:example.com,2026:thing\" style=plain",
    ])
}

private func expectReaderMark(
    _ reader: inout PureYAML.Parsing.Reader,
    line: Int,
    column: Int,
    index: Int,
    advanceAfterCheck: Bool = true,
) {
    #expect(reader.mark == PureYAML.Parsing.Mark(line: line, column: column, index: index))
    if advanceAfterCheck {
        reader.advance()
    }
}

private func expectScannerError(
    _ yaml: String,
    _ expected: PureYAML.Parsing.ParseError,
) {
    expectError(expected) {
        try PureYAML.Parsing.Scanner().scan(yaml)
    }
}
