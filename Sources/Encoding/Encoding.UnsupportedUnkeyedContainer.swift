struct UnsupportedUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var count: Int {
        0
    }

    mutating func encodeNil() throws {
        throw unsupported()
    }

    mutating func encode(_: Bool) throws {
        throw unsupported()
    }

    mutating func encode(_: String) throws {
        throw unsupported()
    }

    mutating func encode(_: Double) throws {
        throw unsupported()
    }

    mutating func encode(_: Float) throws {
        throw unsupported()
    }

    mutating func encode(_: Int) throws {
        throw unsupported()
    }

    mutating func encode(_: Int8) throws {
        throw unsupported()
    }

    mutating func encode(_: Int16) throws {
        throw unsupported()
    }

    mutating func encode(_: Int32) throws {
        throw unsupported()
    }

    mutating func encode(_: Int64) throws {
        throw unsupported()
    }

    mutating func encode(_: UInt) throws {
        throw unsupported()
    }

    mutating func encode(_: UInt8) throws {
        throw unsupported()
    }

    mutating func encode(_: UInt16) throws {
        throw unsupported()
    }

    mutating func encode(_: UInt32) throws {
        throw unsupported()
    }

    mutating func encode(_: UInt64) throws {
        throw unsupported()
    }

    mutating func encode(_: some Encodable) throws {
        throw unsupported()
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy _: NestedKey.Type,
    ) -> KeyedEncodingContainer<NestedKey> {
        KeyedEncodingContainer(UnsupportedKeyedEncodingContainer<NestedKey>(
            codingPath: codingPath + [IndexCodingKey(index: count)],
            userInfo: userInfo,
        ))
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        UnsupportedUnkeyedEncodingContainer(
            codingPath: codingPath + [IndexCodingKey(index: count)],
            userInfo: userInfo,
        )
    }

    mutating func superEncoder() -> any Swift.Encoder {
        PureYAML.Encoding.Encoder(
            codingPath: codingPath + [IndexCodingKey(index: count)],
            userInfo: userInfo,
        )
    }

    private func unsupported() -> PureYAML.Encoding.Error {
        .unsupportedContainer(
            kind: "unkeyed",
            path: PureYAML.Validation.Path(
                codingPath: codingPath + [IndexCodingKey(index: count)],
            ),
        )
    }
}

private struct IndexCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(index: Int) {
        stringValue = "\(index)"
        intValue = index
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
