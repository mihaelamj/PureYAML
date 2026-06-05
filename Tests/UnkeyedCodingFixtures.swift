@testable import PureYAML
import Testing

struct SequenceArticle: Codable, Equatable {
    var title: String
    var tags: [String]
    var ranks: [Int?]
}

struct SequenceCatalog: Codable, Equatable {
    var articles: [SequenceArticle]
    var featured: [String?]
    var empty: [Int]
}

let sequenceArticle = SequenceArticle(
    title: "Typed YAML",
    tags: ["Swift", "YAML"],
    ranks: [1, nil, 3],
)

let sequenceArticleValue = PureYAML.Model.Value.mapping(.init([
    .init(key: "title", value: .string("Typed YAML")),
    .init(key: "tags", value: .sequence([
        .string("Swift"),
        .string("YAML"),
    ])),
    .init(key: "ranks", value: .sequence([
        .int(1),
        .null,
        .int(3),
    ])),
]))

let sequenceCatalog = SequenceCatalog(
    articles: [sequenceArticle],
    featured: ["Typed YAML", nil],
    empty: [],
)

let sequenceCatalogValue = PureYAML.Model.Value.mapping(.init([
    .init(key: "articles", value: .sequence([sequenceArticleValue])),
    .init(key: "featured", value: .sequence([
        .string("Typed YAML"),
        .null,
    ])),
    .init(key: "empty", value: .sequence([])),
]))

struct SequenceDecodeFixture: CustomStringConvertible {
    enum Expectation {
        case integers([Int])
        case optionalStrings([String?])
        case nestedIntegers([[Int]])
        case articles([SequenceArticle])
        case catalog(SequenceCatalog)
    }

    var name: String
    var yaml: String
    var value: PureYAML.Model.Value
    var expectation: Expectation

    var description: String {
        name
    }

    func expectDecodedFromYAML() throws {
        switch expectation {
        case let .integers(expected):
            #expect(try PureYAML.decode([Int].self, from: yaml) == expected)
        case let .optionalStrings(expected):
            #expect(try PureYAML.decode([String?].self, from: yaml) == expected)
        case let .nestedIntegers(expected):
            #expect(try PureYAML.decode([[Int]].self, from: yaml) == expected)
        case let .articles(expected):
            #expect(try PureYAML.decode([SequenceArticle].self, from: yaml) == expected)
        case let .catalog(expected):
            #expect(try PureYAML.decode(SequenceCatalog.self, from: yaml) == expected)
        }
    }

    func expectDecodedFromValue() throws {
        switch expectation {
        case let .integers(expected):
            #expect(try PureYAML.decode([Int].self, from: value) == expected)
        case let .optionalStrings(expected):
            #expect(try PureYAML.decode([String?].self, from: value) == expected)
        case let .nestedIntegers(expected):
            #expect(try PureYAML.decode([[Int]].self, from: value) == expected)
        case let .articles(expected):
            #expect(try PureYAML.decode([SequenceArticle].self, from: value) == expected)
        case let .catalog(expected):
            #expect(try PureYAML.decode(SequenceCatalog.self, from: value) == expected)
        }
    }
}

let sequenceDecodeFixtures: [SequenceDecodeFixture] = [
    .init(
        name: "integer sequence",
        yaml: """
        - 1
        - 2
        - 3
        """,
        value: .sequence([.int(1), .int(2), .int(3)]),
        expectation: .integers([1, 2, 3]),
    ),
    .init(
        name: "optional string sequence",
        yaml: """
        - one
        - null
        - three
        """,
        value: .sequence([
            .string("one"),
            .null,
            .string("three"),
        ]),
        expectation: .optionalStrings(["one", nil, "three"]),
    ),
    .init(
        name: "nested integer sequence",
        yaml: """
        - [1, 2]
        - []
        """,
        value: .sequence([
            .sequence([.int(1), .int(2)]),
            .sequence([]),
        ]),
        expectation: .nestedIntegers([[1, 2], []]),
    ),
    .init(
        name: "sequence of keyed articles",
        yaml: """
        - title: Typed YAML
          tags:
            - Swift
            - YAML
          ranks:
            - 1
            - null
            - 3
        """,
        value: .sequence([sequenceArticleValue]),
        expectation: .articles([sequenceArticle]),
    ),
    .init(
        name: "keyed catalog with sequence properties",
        yaml: """
        articles:
          - title: Typed YAML
            tags: [Swift, YAML]
            ranks: [1, null, 3]
        featured:
          - Typed YAML
          - null
        empty: []
        """,
        value: sequenceCatalogValue,
        expectation: .catalog(sequenceCatalog),
    ),
]
