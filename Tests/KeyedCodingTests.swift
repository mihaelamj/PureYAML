@testable import PureYAML
import Testing

@Suite("Keyed Coding")
struct KeyedCodingTests {
    @Test("Decodes keyed mappings with scalars optionals and nesting")
    func test_decodesKeyedMappingsWithScalarsOptionalsAndNesting() throws {
        let decoded = try PureYAML.decode(KeyedArticle.self, from: keyedArticleValue)

        #expect(decoded == KeyedArticle(
            title: "Typed YAML",
            published: true,
            count: 3,
            ratio: 1.5,
            summary: "Intro",
            missing: nil,
            metadata: .init(author: "Mihaela", rank: 1),
        ))
    }

    @Test("Parses YAML mappings before keyed decoding")
    func test_parsesYAMLMappingsBeforeKeyedDecoding() throws {
        let decoded = try PureYAML.decode(KeyedMetadata.self, from: """
        author: Mihaela
        rank: 1
        """)

        #expect(decoded == .init(author: "Mihaela", rank: 1))
    }

    @Test("Decodes explicit null optionals without requiring missing keys")
    func test_decodesExplicitNullOptionalsWithoutRequiringMissingKeys() throws {
        let decoded = try PureYAML.decode(OptionalArticle.self, from: .mapping(.init([
            .init(key: "title", value: .string("Typed YAML")),
            .init(key: "summary", value: .null),
        ])))

        #expect(decoded == .init(title: "Typed YAML", summary: nil, missing: nil))
    }

    @Test("Encodes keyed structs as exact ordered mappings and YAML")
    func test_encodesKeyedStructsAsExactOrderedMappingsAndYAML() throws {
        let encoded = try PureYAML.encode(keyedArticle)

        #expect(encoded == keyedArticleValue)
        #expect(try PureYAML.encode(EmptyKeyedStruct()) == .mapping(.init()))

        let yaml = try PureYAML.encodeToYAML(keyedArticle)
        #expect(yaml == """
        title: "Typed YAML"
        published: true
        count: 3
        ratio: 1.5
        summary: "Intro"
        metadata:
          author: "Mihaela"
          rank: 1

        """)
        #expect(yaml.contains("title: \"Typed YAML\""))
        #expect(!yaml.contains("missing:"))
    }

    @Test("Keyed decoding failures report exact errors", arguments: keyedDecodingErrorCases)
    func test_keyedDecodingFailuresReportExactErrors(testCase: KeyedDecodingErrorCase) {
        testCase.expectFailure()
    }

    @Test("Keyed decoding validates duplicate keys before reading values")
    func test_keyedDecodingValidatesDuplicateKeysBeforeReadingValues() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("title")]),
            ),
        ]

        expectValidationError(value) { collection in
            #expect(collection.issues == expectedIssues)
            #expect(collection.description == "error: Duplicate mapping key 'title' at $.title")
        }
    }

    @Test("Direct decoders validate duplicate keys by default")
    func test_directDecodersValidateDuplicateKeysByDefault() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))

        expectValidationError(value) { collection in
            #expect(collection.issues == [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
            ])
        } operation: {
            _ = try TitleOnly(from: PureYAML.Decoding.Decoder(value: value))
        }
    }

    @Test("Direct decoders prefix validation paths with coding path")
    func test_directDecodersPrefixValidationPathsWithCodingPath() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))

        expectValidationError(value) { collection in
            #expect(collection.issues == [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("metadata"), .key("title")]),
                ),
            ])
            #expect(collection.description == "error: Duplicate mapping key 'title' at $.metadata.title")
        } operation: {
            _ = try TitleOnly(from: PureYAML.Decoding.Decoder(
                value: value,
                codingPath: [TestCodingKey("metadata")],
            ))
        }
    }

    @Test("Keyed encoding failures report exact errors")
    func test_keyedEncodingFailuresReportExactErrors() {
        expectEncodingError(
            .integerOutOfRange(type: "UInt64", path: .init([.key("value")])),
        ) {
            _ = try PureYAML.encode(WideInteger(value: UInt64.max))
        }
    }

    @Test("Keyed coding error descriptions are exact")
    func test_keyedCodingErrorDescriptionsAreExact() {
        #expect(PureYAML.Decoding.Error.keyNotFound(
            key: "title",
            path: .init([.key("title")]),
        ).description == "Missing required key 'title' at $.title")

        #expect(PureYAML.Decoding.Error.typeMismatch(
            expected: "mapping",
            actual: "string",
            path: .root,
        ).description == "Expected mapping at $, found string")

        #expect(PureYAML.Decoding.Error.valueNotFound(
            path: .init([.index(1)]),
        ).description == "No YAML value found at $[1]")
    }
}

private let keyedArticle = KeyedArticle(
    title: "Typed YAML",
    published: true,
    count: 3,
    ratio: 1.5,
    summary: "Intro",
    missing: nil,
    metadata: .init(author: "Mihaela", rank: 1),
)

private let keyedArticleValue = PureYAML.Model.Value.mapping(.init([
    .init(key: "title", value: .string("Typed YAML")),
    .init(key: "published", value: .bool(true)),
    .init(key: "count", value: .int(3)),
    .init(key: "ratio", value: .double(1.5)),
    .init(key: "summary", value: .string("Intro")),
    .init(key: "metadata", value: .mapping(.init([
        .init(key: "author", value: .string("Mihaela")),
        .init(key: "rank", value: .int(1)),
    ]))),
]))

private let keyedDecodingErrorCases: [KeyedDecodingErrorCase] = [
    .init(
        name: "missing required title",
        value: .mapping(.init([
            .init(key: "published", value: .bool(true)),
            .init(key: "count", value: .int(1)),
            .init(key: "ratio", value: .double(1.0)),
            .init(key: "metadata", value: .mapping(.init([
                .init(key: "author", value: .string("Mihaela")),
                .init(key: "rank", value: .int(1)),
            ]))),
        ])),
        expected: .keyNotFound(key: "title", path: .init([.key("title")])),
        kind: .article,
    ),
    .init(
        name: "title has wrong type",
        value: .mapping(.init([
            .init(key: "title", value: .int(7)),
        ])),
        expected: .typeMismatch(expected: "String", actual: "int", path: .init([.key("title")])),
        kind: .titleOnly,
    ),
    .init(
        name: "keyed root is not mapping",
        value: .string("not a mapping"),
        expected: .typeMismatch(expected: "mapping", actual: "string", path: .root),
        kind: .titleOnly,
    ),
]

private struct KeyedArticle: Codable, Equatable {
    var title: String
    var published: Bool
    var count: Int
    var ratio: Double
    var summary: String?
    var missing: String?
    var metadata: KeyedMetadata
}

private struct KeyedMetadata: Codable, Equatable {
    var author: String
    var rank: Int
}

private struct OptionalArticle: Codable, Equatable {
    var title: String
    var summary: String?
    var missing: String?
}

private struct EmptyKeyedStruct: Codable, Equatable {}

private struct TitleOnly: Codable, Equatable {
    var title: String
}

private struct WideInteger: Encodable {
    var value: UInt64
}

private struct TestCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

struct KeyedDecodingErrorCase: CustomStringConvertible {
    enum Kind {
        case article
        case titleOnly
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
            case .article:
                _ = try PureYAML.decode(KeyedArticle.self, from: value)
            case .titleOnly:
                _ = try PureYAML.decode(TitleOnly.self, from: value)
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
    _: PureYAML.Model.Value,
    check: (PureYAML.Validation.Issue.Collection) -> Void,
    operation: () throws -> some Any,
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

private func expectValidationError(
    _ value: PureYAML.Model.Value,
    check: (PureYAML.Validation.Issue.Collection) -> Void,
) {
    expectValidationError(value, check: check) {
        try PureYAML.decode(TitleOnly.self, from: value)
    }
}
