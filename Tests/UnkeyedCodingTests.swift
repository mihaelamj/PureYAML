@testable import PureYAML
import Testing

@Suite("Unkeyed Coding")
struct UnkeyedCodingTests {
    @Test("Fixture corpus decodes YAML and model sequences", arguments: sequenceDecodeFixtures)
    func test_fixtureCorpusDecodesYAMLAndModelSequences(
        fixture: SequenceDecodeFixture,
    ) throws {
        try fixture.expectDecodedFromYAML()
        try fixture.expectDecodedFromValue()
    }

    @Test("Fixture corpus encodes exact sequence values and YAML", arguments: sequenceEncodeFixtures)
    func test_fixtureCorpusEncodesExactSequenceValuesAndYAML(
        fixture: SequenceEncodeFixture,
    ) throws {
        try fixture.expectEncodedValue()
        try fixture.expectEncodedYAML()
    }

    @Test("Fixture corpus reports exact sequence failures", arguments: sequenceFailureFixtures)
    func test_fixtureCorpusReportsExactSequenceFailures(
        fixture: SequenceFailureFixture,
    ) {
        fixture.expectFailure()
    }

    @Test("Decodes unkeyed sequences with scalars optionals nesting and keyed elements")
    func test_decodesUnkeyedSequencesWithScalarsOptionalsNestingAndKeyedElements() throws {
        #expect(try PureYAML.decode([Int].self, from: .sequence([.int(1), .int(2)])) == [1, 2])

        let optional = try PureYAML.decode([String?].self, from: .sequence([
            .string("one"),
            .null,
            .string("three"),
        ]))
        #expect(optional == ["one", nil, "three"])

        #expect(try PureYAML.decode([[Int]].self, from: nestedIntegerValue) == [[1, 2], []])
        #expect(try PureYAML.decode([ListedArticle].self, from: .sequence([
            listedArticleValue,
        ])) == [listedArticle])
        #expect(try PureYAML.decode(ListedArticle.self, from: listedArticleValue) == listedArticle)
    }

    @Test("Parses YAML sequences before unkeyed decoding")
    func test_parsesYAMLSequencesBeforeUnkeyedDecoding() throws {
        let decoded = try PureYAML.decode([String].self, from: """
        - one
        - two
        """)

        #expect(decoded == ["one", "two"])
    }

    @Test("Encodes unkeyed sequences as exact value trees and YAML")
    func test_encodesUnkeyedSequencesAsExactValueTreesAndYAML() throws {
        let optional: [String?] = ["one", nil, "three"]

        #expect(try PureYAML.encode([1, 2]) == .sequence([.int(1), .int(2)]))
        #expect(try PureYAML.encode(optional) == .sequence([
            .string("one"),
            .null,
            .string("three"),
        ]))
        #expect(try PureYAML.encode([[1, 2], []]) == nestedIntegerValue)
        #expect(try PureYAML.encode([listedArticle]) == .sequence([listedArticleValue]))
        #expect(try PureYAML.encode(listedArticle) == listedArticleValue)
        #expect(try PureYAML.encode([Int]()) == .sequence([]))
        #expect(try PureYAML.encodeToYAML([1, 2]) == """
        - 1
        - 2

        """)
        #expect(try PureYAML.encodeToYAML([Int]()) == "[]\n")
    }

    @Test("Unkeyed super encoders reserve distinct indexes before values are written")
    func test_unkeyedSuperEncodersReserveDistinctIndexesBeforeValuesAreWritten() throws {
        #expect(try PureYAML.encode(SuperEncodedPair()) == .sequence([
            .string("one"),
            .string("two"),
        ]))
    }

    @Test("Unkeyed decoding failures report exact errors", arguments: unkeyedDecodingErrorCases)
    func test_unkeyedDecodingFailuresReportExactErrors(testCase: UnkeyedDecodingErrorCase) {
        testCase.expectFailure()
    }

    @Test("Unkeyed decoding validates before reading values")
    func test_unkeyedDecodingValidatesBeforeReadingValues() {
        let value = PureYAML.Model.Value.sequence([
            .mapping(.init([
                .init(key: "title", value: .string("First")),
                .init(key: "title", value: .string("Second")),
            ])),
        ])

        expectValidationError {
            _ = try PureYAML.decode([TitleOnlyArticle].self, from: value)
        } check: { collection in
            #expect(collection.issues == [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.index(0), .key("title")]),
                ),
            ])
            #expect(collection.description == "error: Duplicate mapping key 'title' at $[0].title")
        }
    }

    @Test("Direct unkeyed containers report overread paths exactly")
    func test_directUnkeyedContainersReportOverreadPathsExactly() throws {
        var container = try PureYAML.Decoding.Decoder(
            value: .sequence([.int(1)]),
        ).unkeyedContainer()

        #expect(try container.decode(Int.self) == 1)
        expectDecodingError(.valueNotFound(path: .init([.index(1)]))) {
            _ = try container.decode(Int.self)
        }
    }

    @Test("Unkeyed encoding failures report exact errors")
    func test_unkeyedEncodingFailuresReportExactErrors() {
        expectEncodingError(
            .integerOutOfRange(type: "UInt64", path: .init([.index(0)])),
        ) {
            _ = try PureYAML.encode([UInt64.max])
        }

        expectEncodingError(
            .integerOutOfRange(type: "UInt64", path: .init([.index(0), .key("value")])),
        ) {
            _ = try PureYAML.encode([WideInteger(value: UInt64.max)])
        }
    }

    @Test("Unkeyed coding error descriptions are exact")
    func test_unkeyedCodingErrorDescriptionsAreExact() {
        #expect(PureYAML.Decoding.Error.valueNotFound(
            path: .init([.index(1)]),
        ).description == "No YAML value found at $[1]")

        #expect(PureYAML.Decoding.Error.typeMismatch(
            expected: "sequence",
            actual: "string",
            path: .root,
        ).description == "Expected sequence at $, found string")

        #expect(PureYAML.Encoding.Error.integerOutOfRange(
            type: "UInt64",
            path: .init([.index(0)]),
        ).description == "UInt64 value is outside PureYAML integer range at $[0]")
    }
}

private let nestedIntegerValue = PureYAML.Model.Value.sequence([
    .sequence([.int(1), .int(2)]),
    .sequence([]),
])

private let listedArticle = ListedArticle(
    title: "Typed YAML",
    tags: ["Swift", "YAML"],
    ranks: [1, nil, 3],
)

private let listedArticleValue = PureYAML.Model.Value.mapping(.init([
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

private let unkeyedDecodingErrorCases: [UnkeyedDecodingErrorCase] = [
    .init(
        name: "root value is not a sequence",
        value: .string("not a sequence"),
        expected: .typeMismatch(expected: "sequence", actual: "string", path: .root),
        kind: .integerArray,
    ),
    .init(
        name: "element has wrong type",
        value: .sequence([.int(1), .string("two")]),
        expected: .typeMismatch(expected: "Int", actual: "string", path: .init([.index(1)])),
        kind: .integerArray,
    ),
    .init(
        name: "nested element has wrong type",
        value: .sequence([
            .sequence([.int(1), .bool(false)]),
        ]),
        expected: .typeMismatch(
            expected: "Int",
            actual: "bool",
            path: .init([.index(0), .index(1)]),
        ),
        kind: .nestedIntegerArray,
    ),
    .init(
        name: "keyed sequence property has wrong type",
        value: .mapping(.init([
            .init(key: "title", value: .string("Typed YAML")),
            .init(key: "tags", value: .string("Swift")),
            .init(key: "ranks", value: .sequence([])),
        ])),
        expected: .typeMismatch(expected: "sequence", actual: "string", path: .init([.key("tags")])),
        kind: .listedArticle,
    ),
]

private struct ListedArticle: Codable, Equatable {
    var title: String
    var tags: [String]
    var ranks: [Int?]
}

private struct TitleOnlyArticle: Codable, Equatable {
    var title: String
}

private struct WideInteger: Encodable {
    var value: UInt64
}

private struct SuperEncodedPair: Encodable {
    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        let first = container.superEncoder()
        let second = container.superEncoder()
        try "one".encode(to: first)
        try "two".encode(to: second)
    }
}

struct UnkeyedDecodingErrorCase: CustomStringConvertible {
    enum Kind {
        case integerArray
        case nestedIntegerArray
        case listedArticle
    }

    var name: String
    var value: PureYAML.Model.Value
    var expected: PureYAML.Decoding.Error
    var kind: Kind

    var description: String {
        name
    }

    func expectFailure() {
        do {
            switch kind {
            case .integerArray:
                _ = try PureYAML.decode([Int].self, from: value)
            case .nestedIntegerArray:
                _ = try PureYAML.decode([[Int]].self, from: value)
            case .listedArticle:
                _ = try PureYAML.decode(ListedArticle.self, from: value)
            }
            recordIssue("expected decoding error")
        } catch let error as PureYAML.Decoding.Error {
            #expect(error == expected)
            #expect(error.description == expected.description)
        } catch {
            recordIssue("unexpected error \(error)")
        }
    }
}

private func expectDecodingError(
    _ expected: PureYAML.Decoding.Error,
    operation: () throws -> some Any,
) {
    do {
        _ = try operation()
        recordIssue("expected decoding error")
    } catch let error as PureYAML.Decoding.Error {
        #expect(error == expected)
        #expect(error.description == expected.description)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}

private func expectEncodingError(
    _ expected: PureYAML.Encoding.Error,
    operation: () throws -> some Any,
) {
    do {
        _ = try operation()
        recordIssue("expected encoding error")
    } catch let error as PureYAML.Encoding.Error {
        #expect(error == expected)
        #expect(error.description == expected.description)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}

private func expectValidationError(
    operation: () throws -> some Any,
    check: (PureYAML.Validation.Issue.Collection) -> Void,
) {
    do {
        _ = try operation()
        recordIssue("expected validation error")
    } catch let collection as PureYAML.Validation.Issue.Collection {
        check(collection)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}
