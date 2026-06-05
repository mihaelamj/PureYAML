@testable import PureYAML
import Testing

@Suite("Parsing Events")
struct ParsingEventTests {
    @Test("Event model represents aliases anchors tags and flow style")
    func test_eventModelRepresentsAliasesAnchorsTagsAndFlowStyle() {
        let mark = PureYAML.Parsing.Mark(line: 2, column: 3, index: 12)
        let events: [PureYAML.Parsing.Event] = [
            .scalar(value: "value", anchor: "root", tag: "!Thing", style: .singleQuoted, mark: mark),
            .sequenceStart(anchor: "items", tag: "!seq", style: .flow, mark: mark),
            .alias(anchor: "root", mark: mark),
        ]

        #expect(events.map(\.description) == [
            "scalar value=\"value\" anchor=root tag=!Thing style=singleQuoted @2:3@12",
            "sequenceStart anchor=items tag=!seq style=flow @2:3@12",
            "alias anchor=root @2:3@12",
        ])
    }

    @Test("Emits golden events for mapping scalars and scalar styles")
    func test_mappingScalarsAndScalarStyles() throws {
        let events = try PureYAML.Parsing.Parser().parseEvents(
            """
            name: "Example"
            single: 'it''s'
            missing:
            """,
        )

        #expect(events.map(\.description) == [
            "streamStart @1:1@0",
            "documentStart @1:1@0",
            "mappingStart anchor=- tag=- style=block @1:1@0",
            "scalar value=\"name\" anchor=- tag=- style=plain @1:1@0",
            "scalar value=\"Example\" anchor=- tag=- style=doubleQuoted @1:7@6",
            "scalar value=\"single\" anchor=- tag=- style=plain @2:1@16",
            "scalar value=\"it's\" anchor=- tag=- style=singleQuoted @2:9@24",
            "scalar value=\"missing\" anchor=- tag=- style=plain @3:1@32",
            "scalar value=\"\" anchor=- tag=- style=plain @3:9@40",
            "mappingEnd @3:9@40",
            "documentEnd @3:9@40",
            "streamEnd @3:9@40",
        ])
    }

    @Test("Emits golden events for nested sequences and mappings")
    func test_nestedSequencesAndMappings() throws {
        let events = try PureYAML.Parsing.Parser().parseEvents(
            """
            servers:
              - url: /
                description: Default
            """,
        )

        #expect(events.map(\.description) == [
            "streamStart @1:1@0",
            "documentStart @1:1@0",
            "mappingStart anchor=- tag=- style=block @1:1@0",
            "scalar value=\"servers\" anchor=- tag=- style=plain @1:1@0",
            "sequenceStart anchor=- tag=- style=block @2:3@11",
            "mappingStart anchor=- tag=- style=block @2:5@13",
            "scalar value=\"url\" anchor=- tag=- style=plain @2:5@13",
            "scalar value=\"/\" anchor=- tag=- style=plain @2:10@18",
            "scalar value=\"description\" anchor=- tag=- style=plain @3:5@24",
            "scalar value=\"Default\" anchor=- tag=- style=plain @3:18@37",
            "mappingEnd @3:25@44",
            "sequenceEnd @3:25@44",
            "mappingEnd @3:25@44",
            "documentEnd @3:25@44",
            "streamEnd @3:25@44",
        ])
        #expect(!events.map(\.description).contains("scalar value=\"\" anchor=- tag=- style=plain @1:1@0"))
    }

    @Test("Emits golden events for flow collections aliases anchors and tags")
    func test_flowCollectionsAliasesAnchorsAndTags() throws {
        let events = try PureYAML.Parsing.Parser().parseEvents(
            """
            flow: [!Thing &item "value", *item, {tagged: !<tag:example.com,2026:thing> 'it''s'}]
            """,
        )

        let descriptions = events.map(\.description)
        #expect(descriptions == [
            "streamStart @1:1@0",
            "documentStart @1:1@0",
            "mappingStart anchor=- tag=- style=block @1:1@0",
            "scalar value=\"flow\" anchor=- tag=- style=plain @1:1@0",
            "sequenceStart anchor=- tag=- style=flow @1:7@6",
            "scalar value=\"value\" anchor=item tag=!Thing style=doubleQuoted @1:8@7",
            "alias anchor=item @1:30@29",
            "mappingStart anchor=- tag=- style=flow @1:37@36",
            "scalar value=\"tagged\" anchor=- tag=- style=plain @1:38@37",
            "scalar value=\"it's\" anchor=- tag=!<tag:example.com,2026:thing> style=singleQuoted @1:46@45",
            "mappingEnd @1:84@83",
            "sequenceEnd @1:85@84",
            "mappingEnd @1:85@84",
            "documentEnd @1:85@84",
            "streamEnd @1:85@84",
        ])
        #expect(!descriptions.contains("sequenceStart anchor=- tag=- style=block @1:7@6"))
        #expect(!descriptions.contains { $0.contains("it''s") })
    }

    @Test("Emits golden events for block scalar headers")
    func test_blockScalarHeaders() throws {
        let events = try PureYAML.Parsing.Parser().parseEvents(
            """
            text: |
              one
              two
            stripped: |-
              one
              two
            folded: >
              one
              two
            """,
        )

        let descriptions = events.map(\.description)
        #expect(descriptions == [
            "streamStart @1:1@0",
            "documentStart @1:1@0",
            "mappingStart anchor=- tag=- style=block @1:1@0",
            "scalar value=\"text\" anchor=- tag=- style=plain @1:1@0",
            "scalar value=\"one\\ntwo\\n\" anchor=- tag=- style=literal @1:7@6",
            "scalar value=\"stripped\" anchor=- tag=- style=plain @4:1@20",
            "scalar value=\"one\\ntwo\" anchor=- tag=- style=literal @4:11@30",
            "scalar value=\"folded\" anchor=- tag=- style=plain @7:1@45",
            "scalar value=\"one two\\n\" anchor=- tag=- style=folded @7:9@53",
            "mappingEnd @9:6@66",
            "documentEnd @9:6@66",
            "streamEnd @9:6@66",
        ])
        #expect(!descriptions.contains { $0.contains("one\\ntwo\\n") && $0.contains("@4:11@30") })
    }

    @Test("Reports parse-event errors")
    func test_errorReporting() {
        expectError(PureYAML.Parsing.ParseError.emptyDocument) {
            try PureYAML.Parsing.Parser().parseEvents("")
        }
        expectError(PureYAML.Parsing.ParseError.unexpectedIndentation(line: 3)) {
            try PureYAML.Parsing.Parser().parseEvents("root:\n    child: yes\n  wrong: no")
        }
        expectError(PureYAML.Parsing.ParseError.unexpectedToken(
            expected: "mapping key",
            actual: "scalar value=\"dangling\" style=plain",
            line: 3,
            column: 3,
        )) {
            try PureYAML.Parsing.Parser().parseEvents("root:\n  child: value\n  dangling")
        }
        expectParseEventError(
            "items: [one, two",
            PureYAML.Parsing.ParseError.unexpectedToken(
                expected: "flow entry or flow sequence end",
                actual: "streamEnd",
                line: 1,
                column: 17,
            ),
            description: "expected flow entry or flow sequence end at line 1, column 17, found streamEnd",
        )
    }
}

private func expectParseEventError(
    _ yaml: String,
    _ expected: PureYAML.Parsing.ParseError,
    description: String,
) {
    do {
        _ = try PureYAML.Parsing.Parser().parseEvents(yaml)
        recordIssue("expected error \(expected)")
    } catch let error as PureYAML.Parsing.ParseError {
        #expect(error == expected)
        #expect(error.description == description)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}
