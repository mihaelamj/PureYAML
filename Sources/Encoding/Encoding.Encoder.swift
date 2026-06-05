public extension PureYAML.Encoding {
    /// Scalar typed encoder that writes a ``PureYAML/Model/Value``.
    final class Encoder: Swift.Encoder {
        public let codingPath: [any CodingKey]
        public let userInfo: [CodingUserInfoKey: Any]

        private let storage: Storage

        public init(
            codingPath: [any CodingKey] = [],
            userInfo: [CodingUserInfoKey: Any] = [:],
        ) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            storage = Storage()
        }

        fileprivate init(
            codingPath: [any CodingKey],
            userInfo: [CodingUserInfoKey: Any],
            storage: Storage,
        ) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.storage = storage
        }

        public func encodedValue() throws -> PureYAML.Model.Value {
            if let error = storage.error {
                throw error
            }

            guard let value = storage.value else {
                throw Error.noValueEncoded(
                    path: PureYAML.Validation.Path(codingPath: codingPath),
                )
            }
            return value
        }

        public func container<Key: CodingKey>(
            keyedBy _: Key.Type,
        ) -> KeyedEncodingContainer<Key> {
            storage.error = .unsupportedContainer(
                kind: "keyed",
                path: PureYAML.Validation.Path(codingPath: codingPath),
            )
            return KeyedEncodingContainer(UnsupportedKeyedEncodingContainer<Key>(
                codingPath: codingPath,
            ))
        }

        public func unkeyedContainer() -> any UnkeyedEncodingContainer {
            storage.error = .unsupportedContainer(
                kind: "unkeyed",
                path: PureYAML.Validation.Path(codingPath: codingPath),
            )
            return UnsupportedUnkeyedEncodingContainer(codingPath: codingPath)
        }

        public func singleValueContainer() -> any SingleValueEncodingContainer {
            SingleValueContainer(storage: storage, codingPath: codingPath)
        }
    }
}

private extension PureYAML.Encoding.Encoder {
    final class Storage {
        var value: PureYAML.Model.Value?
        var error: PureYAML.Encoding.Error?
    }
}

private struct SingleValueContainer: SingleValueEncodingContainer {
    let storage: PureYAML.Encoding.Encoder.Storage
    let codingPath: [any CodingKey]

    mutating func encodeNil() throws {
        storage.error = nil
        storage.value = .null
    }

    mutating func encode(_ value: Bool) throws {
        storage.error = nil
        storage.value = .bool(value)
    }

    mutating func encode(_ value: String) throws {
        storage.error = nil
        storage.value = .string(value)
    }

    mutating func encode(_ value: Double) throws {
        storage.error = nil
        storage.value = .double(value)
    }

    mutating func encode(_ value: Float) throws {
        storage.error = nil
        storage.value = .double(Double(value))
    }

    mutating func encode(_ value: Int) throws {
        storage.error = nil
        storage.value = .int(value)
    }

    mutating func encode(_ value: Int8) throws {
        storage.error = nil
        storage.value = .int(Int(value))
    }

    mutating func encode(_ value: Int16) throws {
        storage.error = nil
        storage.value = .int(Int(value))
    }

    mutating func encode(_ value: Int32) throws {
        storage.error = nil
        storage.value = .int(Int(value))
    }

    mutating func encode(_ value: Int64) throws {
        guard let value = Int(exactly: value) else {
            throw unsupportedInteger("Int64")
        }
        storage.error = nil
        storage.value = .int(value)
    }

    mutating func encode(_ value: UInt) throws {
        guard let value = Int(exactly: value) else {
            throw unsupportedInteger("UInt")
        }
        storage.error = nil
        storage.value = .int(value)
    }

    mutating func encode(_ value: UInt8) throws {
        storage.error = nil
        storage.value = .int(Int(value))
    }

    mutating func encode(_ value: UInt16) throws {
        storage.error = nil
        storage.value = .int(Int(value))
    }

    mutating func encode(_ value: UInt32) throws {
        guard let value = Int(exactly: value) else {
            throw unsupportedInteger("UInt32")
        }
        storage.error = nil
        storage.value = .int(value)
    }

    mutating func encode(_ value: UInt64) throws {
        guard let value = Int(exactly: value) else {
            throw unsupportedInteger("UInt64")
        }
        storage.error = nil
        storage.value = .int(value)
    }

    mutating func encode(_ value: some Encodable) throws {
        try value.encode(to: PureYAML.Encoding.Encoder(
            codingPath: codingPath,
            userInfo: [:],
            storage: storage,
        ))
    }

    private func unsupportedInteger(_ type: String) -> PureYAML.Encoding.Error {
        .integerOutOfRange(
            type: type,
            path: PureYAML.Validation.Path(codingPath: codingPath),
        )
    }
}

private struct UnsupportedKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [any CodingKey]

    mutating func encodeNil(forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: Bool, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: String, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: Double, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: Float, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: Int, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: Int8, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: Int16, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: Int32, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: Int64, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: UInt, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: UInt8, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: UInt16, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: UInt32, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: UInt64, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func encode(_: some Encodable, forKey key: Key) throws {
        throw unsupported(key)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy _: NestedKey.Type,
        forKey key: Key,
    ) -> KeyedEncodingContainer<NestedKey> {
        KeyedEncodingContainer(UnsupportedKeyedEncodingContainer<NestedKey>(
            codingPath: codingPath + [key],
        ))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        UnsupportedUnkeyedEncodingContainer(codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> any Swift.Encoder {
        PureYAML.Encoding.Encoder(codingPath: codingPath, userInfo: [:])
    }

    mutating func superEncoder(forKey key: Key) -> any Swift.Encoder {
        PureYAML.Encoding.Encoder(codingPath: codingPath + [key], userInfo: [:])
    }

    private func unsupported(_ key: Key) -> PureYAML.Encoding.Error {
        .unsupportedContainer(
            kind: "keyed",
            path: PureYAML.Validation.Path(codingPath: codingPath + [key]),
        )
    }
}

private struct UnsupportedUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var codingPath: [any CodingKey]
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
        ))
    }

    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
        UnsupportedUnkeyedEncodingContainer(
            codingPath: codingPath + [IndexCodingKey(index: count)],
        )
    }

    mutating func superEncoder() -> any Swift.Encoder {
        PureYAML.Encoding.Encoder(
            codingPath: codingPath + [IndexCodingKey(index: count)],
            userInfo: [:],
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
