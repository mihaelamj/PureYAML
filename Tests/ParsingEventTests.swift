@testable import PureYAML
import Testing

@Suite("Parsing Events")
struct ParsingEventTests {
    @Test("Event model represents aliases anchors tags and flow style")
    func eventModelRepresentsAliasesAnchorsTagsAndFlowStyle() {
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
    func emitsGoldenEventsForMappingScalarsAndScalarStyles() throws {
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
    func emitsGoldenEventsForNestedSequencesAndMappings() throws {
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
    }
}
