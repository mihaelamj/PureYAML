struct KeyedDecodingContainerImpl<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let mapping: PureYAML.Model.Mapping
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    let validatesInput: Bool

    var allKeys: [Key] {
        mapping.pairs.compactMap { Key(stringValue: $0.key) }
    }

    func contains(_ key: Key) -> Bool {
        mapping[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        try value(for: key) == .null
    }

    func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
        try singleValue(for: key).decode(Bool.self)
    }

    func decode(_: String.Type, forKey key: Key) throws -> String {
        try singleValue(for: key).decode(String.self)
    }

    func decode(_: Double.Type, forKey key: Key) throws -> Double {
        try singleValue(for: key).decode(Double.self)
    }

    func decode(_: Float.Type, forKey key: Key) throws -> Float {
        try singleValue(for: key).decode(Float.self)
    }

    func decode(_: Int.Type, forKey key: Key) throws -> Int {
        try singleValue(for: key).decode(Int.self)
    }

    func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
        try singleValue(for: key).decode(Int8.self)
    }

    func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
        try singleValue(for: key).decode(Int16.self)
    }

    func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
        try singleValue(for: key).decode(Int32.self)
    }

    func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
        try singleValue(for: key).decode(Int64.self)
    }

    func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
        try singleValue(for: key).decode(UInt.self)
    }

    func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try singleValue(for: key).decode(UInt8.self)
    }

    func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try singleValue(for: key).decode(UInt16.self)
    }

    func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try singleValue(for: key).decode(UInt32.self)
    }

    func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try singleValue(for: key).decode(UInt64.self)
    }

    func decode<Value: Decodable>(_: Value.Type, forKey key: Key) throws -> Value {
        try Value(from: decoder(for: key))
    }

    func nestedContainer<NestedKey: CodingKey>(
        keyedBy _: NestedKey.Type,
        forKey key: Key,
    ) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try value(for: key)
        guard case let .mapping(mapping) = value else {
            throw PureYAML.Decoding.Error.typeMismatch(
                expected: "mapping",
                actual: value.kindDescription,
                path: PureYAML.Validation.Path(codingPath: codingPath + [key]),
            )
        }

        return KeyedDecodingContainer(KeyedDecodingContainerImpl<NestedKey>(
            mapping: mapping,
            codingPath: codingPath + [key],
            userInfo: userInfo,
            validatesInput: validatesInput,
        ))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
        let value = try value(for: key)
        try validateIfNeeded(value, forKey: key)
        throw PureYAML.Decoding.Error.unsupportedContainer(
            kind: "unkeyed",
            path: PureYAML.Validation.Path(codingPath: codingPath + [key]),
        )
    }

    func superDecoder() throws -> any Swift.Decoder {
        PureYAML.Decoding.Decoder(
            value: .mapping(mapping),
            codingPath: codingPath,
            userInfo: userInfo,
            validatesInput: validatesInput,
        )
    }

    func superDecoder(forKey key: Key) throws -> any Swift.Decoder {
        try decoder(for: key)
    }

    private func singleValue(for key: Key) throws -> any SingleValueDecodingContainer {
        try decoder(for: key).singleValueContainer()
    }

    private func decoder(for key: Key) throws -> PureYAML.Decoding.Decoder {
        try PureYAML.Decoding.Decoder(
            value: value(for: key),
            codingPath: codingPath + [key],
            userInfo: userInfo,
            validatesInput: validatesInput,
        )
    }

    private func value(for key: Key) throws -> PureYAML.Model.Value {
        guard let value = mapping[key.stringValue] else {
            throw PureYAML.Decoding.Error.keyNotFound(
                key: key.stringValue,
                path: PureYAML.Validation.Path(codingPath: codingPath + [key]),
            )
        }
        return value
    }

    private func validateIfNeeded(
        _ value: PureYAML.Model.Value,
        forKey key: Key,
    ) throws {
        if validatesInput {
            try PureYAML.Decoding.validate(value, codingPath: codingPath + [key])
        }
    }
}
