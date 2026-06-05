@testable import PureYAML
import Testing

struct SequenceEncodeFixture: CustomStringConvertible {
    enum Subject {
        case integers([Int])
        case optionalStrings([String?])
        case nestedIntegers([[Int]])
        case articles([SequenceArticle])
        case catalog(SequenceCatalog)
    }

    var name: String
    var subject: Subject
    var expectedValue: PureYAML.Model.Value
    var expectedYAML: String
    var forbiddenYAMLFragments: [String]

    var description: String {
        name
    }

    func expectEncodedValue() throws {
        switch subject {
        case let .integers(value):
            #expect(try PureYAML.encode(value) == expectedValue)
        case let .optionalStrings(value):
            #expect(try PureYAML.encode(value) == expectedValue)
        case let .nestedIntegers(value):
            #expect(try PureYAML.encode(value) == expectedValue)
        case let .articles(value):
            #expect(try PureYAML.encode(value) == expectedValue)
        case let .catalog(value):
            #expect(try PureYAML.encode(value) == expectedValue)
        }
    }

    func expectEncodedYAML() throws {
        let yaml = try encodedYAML()
        #expect(yaml == expectedYAML)
        for fragment in forbiddenYAMLFragments {
            #expect(!yaml.contains(fragment))
        }
    }

    private func encodedYAML() throws -> String {
        switch subject {
        case let .integers(value):
            try PureYAML.encodeToYAML(value)
        case let .optionalStrings(value):
            try PureYAML.encodeToYAML(value)
        case let .nestedIntegers(value):
            try PureYAML.encodeToYAML(value)
        case let .articles(value):
            try PureYAML.encodeToYAML(value)
        case let .catalog(value):
            try PureYAML.encodeToYAML(value)
        }
    }
}

let sequenceEncodeFixtures: [SequenceEncodeFixture] = [
    .init(
        name: "integer sequence",
        subject: .integers([1, 2, 3]),
        expectedValue: .sequence([.int(1), .int(2), .int(3)]),
        expectedYAML: """
        - 1
        - 2
        - 3

        """,
        forbiddenYAMLFragments: ["null", "title:"],
    ),
    .init(
        name: "optional string sequence",
        subject: .optionalStrings(["one", nil, "three"]),
        expectedValue: .sequence([
            .string("one"),
            .null,
            .string("three"),
        ]),
        expectedYAML: """
        - "one"
        - null
        - "three"

        """,
        forbiddenYAMLFragments: ["- 0"],
    ),
    .init(
        name: "nested integer sequence",
        subject: .nestedIntegers([[1, 2], []]),
        expectedValue: .sequence([
            .sequence([.int(1), .int(2)]),
            .sequence([]),
        ]),
        expectedYAML: """
        -
          - 1
          - 2
        -

        """,
        forbiddenYAMLFragments: ["null"],
    ),
    .init(
        name: "sequence of keyed articles",
        subject: .articles([sequenceArticle]),
        expectedValue: .sequence([sequenceArticleValue]),
        expectedYAML: """
        -
          title: "Typed YAML"
          tags:
            - "Swift"
            - "YAML"
          ranks:
            - 1
            - null
            - 3

        """,
        forbiddenYAMLFragments: ["missing:", "empty:"],
    ),
    .init(
        name: "keyed catalog with sequence properties",
        subject: .catalog(sequenceCatalog),
        expectedValue: sequenceCatalogValue,
        expectedYAML: """
        articles:
          -
            title: "Typed YAML"
            tags:
              - "Swift"
              - "YAML"
            ranks:
              - 1
              - null
              - 3
        featured:
          - "Typed YAML"
          - null
        empty:

        """,
        forbiddenYAMLFragments: ["missing:", "- 0"],
    ),
]
