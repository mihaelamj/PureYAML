@testable import PureYAML

let dynamicSettingsValue = PureYAML.Model.Value.mapping(.init([
    .init(key: "/users", value: .int(2)),
    .init(key: "name.with.dot", value: .int(3)),
]))

let nestedCompatibilityValue = PureYAML.Model.Value.mapping(.init([
    .init(key: "title", value: .string("Typed YAML")),
    .init(key: "metadata", value: .mapping(.init([
        .init(key: "author", value: .string("Mihaela")),
        .init(key: "rating", value: .int(5)),
    ]))),
    .init(key: "sections", value: .sequence([
        .mapping(.init([
            .init(key: "heading", value: .string("Intro")),
            .init(key: "items", value: .sequence([
                .string("one"),
                .string("two"),
            ])),
        ])),
        .mapping(.init([
            .init(key: "heading", value: .string("Outro")),
            .init(key: "items", value: .sequence([])),
        ])),
    ])),
]))

let nestedCompatibilityFixture = NestedCompatibilityDocument(
    title: "Typed YAML",
    metadata: .init(author: "Mihaela", rating: 5),
    sections: [
        .init(heading: "Intro", items: ["one", "two"]),
        .init(heading: "Outro", items: []),
    ],
)

let codingPathProbeValue = PureYAML.Model.Value.mapping(.init([
    .init(key: "payload", value: .string("child")),
    .init(key: "metadata", value: .mapping(.init([
        .init(key: "author", value: .string("Mihaela")),
    ]))),
    .init(key: "items", value: .sequence([
        .mapping(.init([
            .init(key: "author", value: .string("Nested")),
        ])),
    ])),
]))

struct DynamicSettings: Codable, Equatable {
    struct Entry: Equatable {
        var key: String
        var value: Int
    }

    var entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        entries = try container.allKeys.map { key in
            try Entry(
                key: key.stringValue,
                value: container.decode(Int.self, forKey: key),
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for entry in entries {
            try container.encode(
                entry.value,
                forKey: DynamicCodingKey(entry.key),
            )
        }
    }
}

struct NestedCompatibilityDocument: Codable, Equatable {
    var title: String
    var metadata: NestedCompatibilityMetadata
    var sections: [NestedCompatibilitySection]
}

struct NestedCompatibilityMetadata: Codable, Equatable {
    var author: String
    var rating: Int
}

struct NestedCompatibilitySection: Codable, Equatable {
    var heading: String
    var items: [String]
}

struct SuperCodedPayload: Codable, Equatable {
    var value: String
}

struct KeyedSuperBox: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case payload
    }

    var payload: SuperCodedPayload

    init(payload: SuperCodedPayload) {
        self.payload = payload
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        payload = try SuperCodedPayload(
            from: container.superDecoder(forKey: .payload),
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try payload.encode(to: container.superEncoder(forKey: .payload))
    }
}

struct KeyedDefaultSuperBox: Codable, Equatable {
    var payload: SuperCodedPayload

    init(payload: SuperCodedPayload) {
        self.payload = payload
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingPathProbeTopKey.self)
        let superDecoder = try container.superDecoder()
        expectCodingPath(superDecoder.codingPath, strings: ["super"], intValues: [nil])
        payload = try SuperCodedPayload(from: superDecoder)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingPathProbeTopKey.self)
        let superEncoder = container.superEncoder()
        expectCodingPath(superEncoder.codingPath, strings: ["super"], intValues: [nil])
        try payload.encode(to: superEncoder)
    }
}

struct DelayedKeyedSuperEncoders: Encodable {
    enum CodingKeys: String, CodingKey {
        case first
        case second
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let first = container.superEncoder(forKey: .first)
        let second = container.superEncoder(forKey: .second)
        try "two".encode(to: second)
        try "one".encode(to: first)
    }
}

struct MissingPayloadBox: Decodable {
    enum CodingKeys: String, CodingKey {
        case payload
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.superDecoder(forKey: .payload)
    }
}

struct MissingDefaultSuperBox: Decodable {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingPathProbeTopKey.self)
        _ = try container.superDecoder()
    }
}

struct NoValueEncoded: Encodable {
    func encode(to _: any Encoder) throws {}
}

struct KeyedCodingPathEncodingProbe: Encodable {
    func encode(to encoder: any Encoder) throws {
        expectCodingPath(encoder.codingPath, strings: [], intValues: [])

        var container = encoder.container(keyedBy: CodingPathProbeTopKey.self)
        expectCodingPath(container.codingPath, strings: [], intValues: [])

        let superEncoder = container.superEncoder(forKey: .payload)
        expectCodingPath(superEncoder.codingPath, strings: ["payload"], intValues: [nil])

        var metadata = container.nestedContainer(
            keyedBy: CodingPathProbeNestedKey.self,
            forKey: .metadata,
        )
        expectCodingPath(metadata.codingPath, strings: ["metadata"], intValues: [nil])
        try metadata.encode("Mihaela", forKey: .author)

        var items = container.nestedUnkeyedContainer(forKey: .items)
        expectCodingPath(items.codingPath, strings: ["items"], intValues: [nil])

        var item = items.nestedContainer(keyedBy: CodingPathProbeNestedKey.self)
        expectCodingPath(item.codingPath, strings: ["items", "0"], intValues: [nil, 0])
        try item.encode("Nested", forKey: .author)

        try "child".encode(to: superEncoder)
    }
}

struct KeyedCodingPathDecodingProbe: Decodable {
    init(from decoder: any Decoder) throws {
        expectCodingPath(decoder.codingPath, strings: [], intValues: [])

        let container = try decoder.container(keyedBy: CodingPathProbeTopKey.self)
        expectCodingPath(container.codingPath, strings: [], intValues: [])

        let superDecoder = try container.superDecoder(forKey: .payload)
        expectCodingPath(superDecoder.codingPath, strings: ["payload"], intValues: [nil])
        _ = try superDecoder.singleValueContainer().decode(String.self)

        let metadata = try container.nestedContainer(
            keyedBy: CodingPathProbeNestedKey.self,
            forKey: .metadata,
        )
        expectCodingPath(metadata.codingPath, strings: ["metadata"], intValues: [nil])
        _ = try metadata.decode(String.self, forKey: .author)

        var items = try container.nestedUnkeyedContainer(forKey: .items)
        expectCodingPath(items.codingPath, strings: ["items"], intValues: [nil])

        let item = try items.nestedContainer(keyedBy: CodingPathProbeNestedKey.self)
        expectCodingPath(item.codingPath, strings: ["items", "0"], intValues: [nil, 0])
        _ = try item.decode(String.self, forKey: .author)
    }
}

enum CodingPathProbeTopKey: String, CodingKey {
    case payload
    case metadata
    case items
}

enum CodingPathProbeNestedKey: String, CodingKey {
    case author
}

struct DynamicCodingKey: CodingKey {
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
