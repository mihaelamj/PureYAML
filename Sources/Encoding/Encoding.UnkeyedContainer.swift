struct UnkeyedEncodingContainerImpl: UnkeyedEncodingContainer {
    let storage: PureYAML.Encoding.Encoder.Storage
    var codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any]
    var count: Int {
        if case let .sequence(values) = storage.value {
            return values.count
        }
        return 0
    }

    init(
        storage: PureYAML.Encoding.Encoder.Storage,
        codingPath: [any CodingKey],
        userInfo: [CodingUserInfoKey: Any],
    ) {
        self.storage = storage
        self.codingPath = codingPath
        self.userInfo = userInfo
        if storage.value == nil {
            storage.set(.sequence([]))
        }
    }

    mutating func encodeNil() throws {
        storage.append(.null)
    }

    mutating func encode(_ value: Bool) throws {
        storage.append(.bool(value))
    }

    mutating func encode(_ value: String) throws {
        storage.append(.string(value))
    }

    mutating func encode(_ value: Double) throws {
        storage.append(.double(value))
    }

    mutating func encode(_ value: Float) throws {
        storage.append(.double(Double(value)))
    }

    mutating func encode(_ value: Int) throws {
        storage.append(.int(value))
    }

    mutating func encode(_ value: Int8) throws {
        storage.append(.int(Int(value)))
    }

    mutating func encode(_ value: Int16) throws {
        storage.append(.int(Int(value)))
    }

    mutating func encode(_ value: Int32) throws {
        storage.append(.int(Int(value)))
    }

    mutating func encode(_ value: Int64) throws {
        guard let value = Int(exactly: value) else {
            throw integerOutOfRange("Int64")
        }
        storage.append(.int(value))
    }

    mutating func encode(_ value: UInt) throws {
        guard let value = Int(exactly: value) else {
            throw integerOutOfRange("UInt")
        }
        storage.append(.int(value))
    }

    mutating func encode(_ value: UInt8) throws {
        storage.append(.int(Int(value)))
    }

    mutating func encode(_ value: UInt16) throws {
        storage.append(.int(Int(value)))
    }

    mutating func encode(_ value: UInt32) throws {
        guard let value = Int(exactly: value) else {
            throw integerOutOfRange("UInt32")
        }
        storage.append(.int(value))
    }

    mutating func encode(_ value: UInt64) throws {
        guard let value = Int(exactly: value) else {
            throw integerOutOfRange("UInt64")
        }
        storage.append(.int(value))
    }

    mutating func encode(_ value: some Encodable) throws {
        let index = count
        let childStorage = PureYAML.Encoding.Encoder.Storage(
            parent: storage,
            parentIndex: index,
        )
        let childEncoder = PureYAML.Encoding.Encoder(
            codingPath: codingPath + [IndexCodingKey(index: index)],
            userInfo: userInfo,
            storage: childStorage,
        )
        try value.encode(to: childEncoder)
        _ = try childEncoder.encodedValue()
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy _: NestedKey.Type,
    ) -> KeyedEncodingContainer<NestedKey> {
        let index = count
        let childStorage = PureYAML.Encoding.Encoder.Storage(
            parent: storage,
            parentIndex: index,
        )
        return KeyedEncodingContainer(KeyedEncodingContainerImpl<NestedKey>(
            storage: childStorage,
            codingPath: codingPath + [IndexCodingKey(index: index)],
            userInfo: userInfo,
        ))
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        let index = count
        let childStorage = PureYAML.Encoding.Encoder.Storage(
            parent: storage,
            parentIndex: index,
        )
        return UnkeyedEncodingContainerImpl(
            storage: childStorage,
            codingPath: codingPath + [IndexCodingKey(index: index)],
            userInfo: userInfo,
        )
    }

    mutating func superEncoder() -> any Swift.Encoder {
        let index = count
        storage.append(.null)
        let childStorage = PureYAML.Encoding.Encoder.Storage(
            parent: storage,
            parentIndex: index,
        )
        return PureYAML.Encoding.Encoder(
            codingPath: codingPath + [IndexCodingKey(index: index)],
            userInfo: userInfo,
            storage: childStorage,
        )
    }

    private func integerOutOfRange(_ type: String) -> PureYAML.Encoding.Error {
        .integerOutOfRange(
            type: type,
            path: PureYAML.Validation.Path(codingPath: codingPath + [IndexCodingKey(index: count)]),
        )
    }
}
