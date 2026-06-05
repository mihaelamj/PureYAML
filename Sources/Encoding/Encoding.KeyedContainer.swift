struct KeyedEncodingContainerImpl<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let storage: PureYAML.Encoding.Encoder.Storage
    var codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    init(
        storage: PureYAML.Encoding.Encoder.Storage,
        codingPath: [any CodingKey],
        userInfo: [CodingUserInfoKey: Any],
    ) {
        self.storage = storage
        self.codingPath = codingPath
        self.userInfo = userInfo
        if storage.value == nil {
            storage.set(.mapping(.init()))
        }
    }

    mutating func encodeNil(forKey key: Key) throws {
        storage.set(.null, forKey: key.stringValue)
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        storage.set(.bool(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        storage.set(.string(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        storage.set(.double(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        storage.set(.double(Double(value)), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        storage.set(.int(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        storage.set(.int(Int(value)), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        storage.set(.int(Int(value)), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        storage.set(.int(Int(value)), forKey: key.stringValue)
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        guard let value = Int(exactly: value) else {
            throw integerOutOfRange("Int64", at: key)
        }
        storage.set(.int(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        guard let value = Int(exactly: value) else {
            throw integerOutOfRange("UInt", at: key)
        }
        storage.set(.int(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        storage.set(.int(Int(value)), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        storage.set(.int(Int(value)), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        guard let value = Int(exactly: value) else {
            throw integerOutOfRange("UInt32", at: key)
        }
        storage.set(.int(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        guard let value = Int(exactly: value) else {
            throw integerOutOfRange("UInt64", at: key)
        }
        storage.set(.int(value), forKey: key.stringValue)
    }

    mutating func encode(_ value: some Encodable, forKey key: Key) throws {
        let childStorage = PureYAML.Encoding.Encoder.Storage(
            parent: storage,
            parentKey: key.stringValue,
        )
        let childEncoder = PureYAML.Encoding.Encoder(
            codingPath: codingPath + [key],
            userInfo: userInfo,
            storage: childStorage,
        )
        try value.encode(to: childEncoder)
        _ = try childEncoder.encodedValue()
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy _: NestedKey.Type,
        forKey key: Key,
    ) -> KeyedEncodingContainer<NestedKey> {
        let childStorage = PureYAML.Encoding.Encoder.Storage(
            parent: storage,
            parentKey: key.stringValue,
        )
        return KeyedEncodingContainer(KeyedEncodingContainerImpl<NestedKey>(
            storage: childStorage,
            codingPath: codingPath + [key],
            userInfo: userInfo,
        ))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        let childStorage = PureYAML.Encoding.Encoder.Storage(
            parent: storage,
            parentKey: key.stringValue,
        )
        return UnkeyedEncodingContainerImpl(
            storage: childStorage,
            codingPath: codingPath + [key],
            userInfo: userInfo,
        )
    }

    mutating func superEncoder() -> any Swift.Encoder {
        PureYAML.Encoding.Encoder(
            codingPath: codingPath,
            userInfo: userInfo,
            storage: storage,
        )
    }

    mutating func superEncoder(forKey key: Key) -> any Swift.Encoder {
        let childStorage = PureYAML.Encoding.Encoder.Storage(
            parent: storage,
            parentKey: key.stringValue,
        )
        return PureYAML.Encoding.Encoder(
            codingPath: codingPath + [key],
            userInfo: userInfo,
            storage: childStorage,
        )
    }

    private func integerOutOfRange(
        _ type: String,
        at key: Key,
    ) -> PureYAML.Encoding.Error {
        .integerOutOfRange(
            type: type,
            path: PureYAML.Validation.Path(codingPath: codingPath + [key]),
        )
    }
}
