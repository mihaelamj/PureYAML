struct UnkeyedDecodingContainerImpl: UnkeyedDecodingContainer {
    let values: [PureYAML.Model.Value]
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    let validatesInput: Bool
    var currentIndex: Int = 0

    var count: Int? {
        values.count
    }

    var isAtEnd: Bool {
        currentIndex >= values.count
    }

    mutating func decodeNil() throws -> Bool {
        let value = try currentValue()
        guard value == .null else {
            return false
        }
        currentIndex += 1
        return true
    }

    mutating func decode(_: Bool.Type) throws -> Bool {
        try decodeSingleValue(Bool.self)
    }

    mutating func decode(_: String.Type) throws -> String {
        try decodeSingleValue(String.self)
    }

    mutating func decode(_: Double.Type) throws -> Double {
        try decodeSingleValue(Double.self)
    }

    mutating func decode(_: Float.Type) throws -> Float {
        try decodeSingleValue(Float.self)
    }

    mutating func decode(_: Int.Type) throws -> Int {
        try decodeSingleValue(Int.self)
    }

    mutating func decode(_: Int8.Type) throws -> Int8 {
        try decodeSingleValue(Int8.self)
    }

    mutating func decode(_: Int16.Type) throws -> Int16 {
        try decodeSingleValue(Int16.self)
    }

    mutating func decode(_: Int32.Type) throws -> Int32 {
        try decodeSingleValue(Int32.self)
    }

    mutating func decode(_: Int64.Type) throws -> Int64 {
        try decodeSingleValue(Int64.self)
    }

    mutating func decode(_: UInt.Type) throws -> UInt {
        try decodeSingleValue(UInt.self)
    }

    mutating func decode(_: UInt8.Type) throws -> UInt8 {
        try decodeSingleValue(UInt8.self)
    }

    mutating func decode(_: UInt16.Type) throws -> UInt16 {
        try decodeSingleValue(UInt16.self)
    }

    mutating func decode(_: UInt32.Type) throws -> UInt32 {
        try decodeSingleValue(UInt32.self)
    }

    mutating func decode(_: UInt64.Type) throws -> UInt64 {
        try decodeSingleValue(UInt64.self)
    }

    mutating func decode<Value: Decodable>(_: Value.Type) throws -> Value {
        let value = try Value(from: decoderForCurrentIndex())
        currentIndex += 1
        return value
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy _: NestedKey.Type,
    ) throws -> KeyedDecodingContainer<NestedKey> {
        let index = currentIndex
        let value = try currentValue()
        guard case let .mapping(mapping) = value else {
            throw PureYAML.Decoding.Error.typeMismatch(
                expected: "mapping",
                actual: value.kindDescription,
                path: PureYAML.Validation.Path(codingPath: codingPath + [IndexCodingKey(index: index)]),
            )
        }

        currentIndex += 1
        return KeyedDecodingContainer(KeyedDecodingContainerImpl<NestedKey>(
            mapping: mapping,
            codingPath: codingPath + [IndexCodingKey(index: index)],
            userInfo: userInfo,
            validatesInput: validatesInput,
        ))
    }

    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        let index = currentIndex
        let value = try currentValue()
        guard case let .sequence(values) = value else {
            throw PureYAML.Decoding.Error.typeMismatch(
                expected: "sequence",
                actual: value.kindDescription,
                path: PureYAML.Validation.Path(codingPath: codingPath + [IndexCodingKey(index: index)]),
            )
        }

        currentIndex += 1
        return UnkeyedDecodingContainerImpl(
            values: values,
            codingPath: codingPath + [IndexCodingKey(index: index)],
            userInfo: userInfo,
            validatesInput: validatesInput,
        )
    }

    mutating func superDecoder() throws -> any Swift.Decoder {
        let decoder = try decoderForCurrentIndex()
        currentIndex += 1
        return decoder
    }

    private mutating func decodeSingleValue<Value: Decodable>(
        _ type: Value.Type,
    ) throws -> Value {
        let value = try decoderForCurrentIndex().singleValueContainer().decode(type)
        currentIndex += 1
        return value
    }

    private func decoderForCurrentIndex() throws -> PureYAML.Decoding.Decoder {
        try PureYAML.Decoding.Decoder(
            value: currentValue(),
            codingPath: codingPath + [IndexCodingKey(index: currentIndex)],
            userInfo: userInfo,
            validatesInput: validatesInput,
        )
    }

    private func currentValue() throws -> PureYAML.Model.Value {
        guard currentIndex < values.count else {
            throw PureYAML.Decoding.Error.valueNotFound(
                path: PureYAML.Validation.Path(codingPath: codingPath + [IndexCodingKey(index: currentIndex)]),
            )
        }
        return values[currentIndex]
    }
}
