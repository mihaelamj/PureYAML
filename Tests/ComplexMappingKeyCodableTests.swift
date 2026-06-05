@testable import PureYAML
import Testing

@Suite("Complex Mapping Key Codable")
struct ComplexMappingKeyCodableTests {
    @Test("Keeps keyed Codable string-only for documents with complex keys")
    func test_keepsKeyedCodableStringOnlyForDocumentsWithComplexKeys() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(keyNode: .sequence([.string("ignored")]), value: .int(1)),
            .init(key: "title", value: .string("Visible")),
        ]))

        let decoded = try PureYAML.decode(CodingKeyListProbe.self, from: value)

        #expect(decoded.keys == ["title"])
        #expect(try PureYAML.decode(TitleOnly.self, from: value) == .init(title: "Visible"))
        do {
            _ = try PureYAML.decode(ComplexKeyProbe.self, from: value)
            recordIssue("expected key-not-found error")
        } catch let error as PureYAML.Decoding.Error {
            #expect(error == .keyNotFound(
                key: "[\"ignored\"]",
                path: .init([.key("[\"ignored\"]")]),
            ))
            #expect(error.description == """
            Missing required key '[\"ignored\"]' at $["[\\\"ignored\\\"]"]
            """)
        }
    }
}

private struct TitleOnly: Decodable, Equatable {
    var title: String
}

private struct CodingKeyListProbe: Decodable, Equatable {
    var keys: [String]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        keys = container.allKeys.map(\.stringValue)
    }
}

private struct ComplexKeyProbe: Decodable {
    enum CodingKeys: String, CodingKey {
        case ignored = "[\"ignored\"]"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decode(Int.self, forKey: .ignored)
    }
}
