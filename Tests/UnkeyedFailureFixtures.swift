@testable import PureYAML
import Testing

struct SequenceFailureFixture: CustomStringConvertible {
    enum Operation {
        case decodeIntegers
        case decodeNestedIntegers
        case decodeArticles
        case decodeCatalog
    }

    enum Expected {
        case decoding(PureYAML.Decoding.Error)
        case validation([PureYAML.Validation.Issue], String)
    }

    var name: String
    var value: PureYAML.Model.Value
    var operation: Operation
    var expected: Expected

    var description: String {
        name
    }

    func expectFailure() {
        do {
            switch operation {
            case .decodeIntegers:
                _ = try PureYAML.decode([Int].self, from: value)
            case .decodeNestedIntegers:
                _ = try PureYAML.decode([[Int]].self, from: value)
            case .decodeArticles:
                _ = try PureYAML.decode([SequenceArticle].self, from: value)
            case .decodeCatalog:
                _ = try PureYAML.decode(SequenceCatalog.self, from: value)
            }
            recordIssue("expected fixture failure")
        } catch let error as PureYAML.Decoding.Error {
            guard case let .decoding(expected) = expected else {
                recordIssue("unexpected decoding error \(error)")
                return
            }
            #expect(error == expected)
            #expect(error.description == expected.description)
        } catch let collection as PureYAML.Validation.Issue.Collection {
            guard case let .validation(issues, description) = expected else {
                recordIssue("unexpected validation error \(collection)")
                return
            }
            #expect(collection.issues == issues)
            #expect(collection.description == description)
        } catch {
            recordIssue("unexpected error \(error)")
        }
    }
}

let sequenceFailureFixtures: [SequenceFailureFixture] = [
    .init(
        name: "sequence root is required",
        value: .string("not a sequence"),
        operation: .decodeIntegers,
        expected: .decoding(.typeMismatch(expected: "sequence", actual: "string", path: .root)),
    ),
    .init(
        name: "integer sequence rejects string element",
        value: .sequence([.int(1), .string("two")]),
        operation: .decodeIntegers,
        expected: .decoding(.typeMismatch(expected: "Int", actual: "string", path: .init([.index(1)]))),
    ),
    .init(
        name: "nested integer sequence rejects bool element",
        value: .sequence([
            .sequence([.int(1), .bool(false)]),
        ]),
        operation: .decodeNestedIntegers,
        expected: .decoding(.typeMismatch(
            expected: "Int",
            actual: "bool",
            path: .init([.index(0), .index(1)]),
        )),
    ),
    .init(
        name: "article sequence rejects missing title",
        value: .sequence([
            .mapping(.init([
                .init(key: "tags", value: .sequence([])),
                .init(key: "ranks", value: .sequence([])),
            ])),
        ]),
        operation: .decodeArticles,
        expected: .decoding(.keyNotFound(key: "title", path: .init([.index(0), .key("title")]))),
    ),
    .init(
        name: "catalog rejects non-sequence tags",
        value: .mapping(.init([
            .init(key: "articles", value: .sequence([
                .mapping(.init([
                    .init(key: "title", value: .string("Typed YAML")),
                    .init(key: "tags", value: .string("Swift")),
                    .init(key: "ranks", value: .sequence([])),
                ])),
            ])),
            .init(key: "featured", value: .sequence([])),
            .init(key: "empty", value: .sequence([])),
        ])),
        operation: .decodeCatalog,
        expected: .decoding(.typeMismatch(
            expected: "sequence",
            actual: "string",
            path: .init([.key("articles"), .index(0), .key("tags")]),
        )),
    ),
    .init(
        name: "duplicate keys in sequence are validation failures before decoding",
        value: .sequence([
            .mapping(.init([
                .init(key: "title", value: .string("First")),
                .init(key: "title", value: .string("Second")),
                .init(key: "tags", value: .sequence([])),
                .init(key: "ranks", value: .sequence([])),
            ])),
        ]),
        operation: .decodeArticles,
        expected: .validation(
            [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.index(0), .key("title")]),
                ),
            ],
            "error: Duplicate mapping key 'title' at $[0].title",
        ),
    ),
]
