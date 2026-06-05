public extension PureYAML.Encoding {
    /// Typed encoder that writes a ``PureYAML/Model/Value``.
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

        init(
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
            storage.set(.mapping(.init()))
            return KeyedEncodingContainer(KeyedEncodingContainerImpl<Key>(
                storage: storage,
                codingPath: codingPath,
                userInfo: userInfo,
            ))
        }

        public func unkeyedContainer() -> any UnkeyedEncodingContainer {
            storage.fail(.unsupportedContainer(
                kind: "unkeyed",
                path: PureYAML.Validation.Path(codingPath: codingPath),
            ))
            return UnsupportedUnkeyedEncodingContainer(
                codingPath: codingPath,
                userInfo: userInfo,
            )
        }

        public func singleValueContainer() -> any SingleValueEncodingContainer {
            SingleValueContainer(
                storage: storage,
                codingPath: codingPath,
                userInfo: userInfo,
            )
        }
    }
}

extension PureYAML.Encoding.Encoder {
    final class Storage {
        var value: PureYAML.Model.Value?
        var error: PureYAML.Encoding.Error?
        private let parent: Storage?
        private let parentKey: String?

        init(
            parent: Storage? = nil,
            parentKey: String? = nil,
        ) {
            self.parent = parent
            self.parentKey = parentKey
        }

        func set(_ value: PureYAML.Model.Value) {
            self.value = value
            if let parent, let parentKey {
                parent.set(value, forKey: parentKey)
            }
        }

        func set(
            _ value: PureYAML.Model.Value,
            forKey key: String,
        ) {
            var mapping: PureYAML.Model.Mapping = if case let .mapping(existing) = self.value {
                existing
            } else {
                .init()
            }

            if let index = mapping.pairs.firstIndex(where: { $0.key == key }) {
                mapping.pairs[index] = .init(key: key, value: value)
            } else {
                mapping.pairs.append(.init(key: key, value: value))
            }
            set(.mapping(mapping))
        }

        func fail(_ error: PureYAML.Encoding.Error) {
            self.error = error
            parent?.fail(error)
        }
    }
}

private struct SingleValueContainer: SingleValueEncodingContainer {
    let storage: PureYAML.Encoding.Encoder.Storage
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    mutating func encodeNil() throws {
        storage.set(.null)
    }

    mutating func encode(_ value: Bool) throws {
        storage.set(.bool(value))
    }

    mutating func encode(_ value: String) throws {
        storage.set(.string(value))
    }

    mutating func encode(_ value: Double) throws {
        storage.set(.double(value))
    }

    mutating func encode(_ value: Float) throws {
        storage.set(.double(Double(value)))
    }

    mutating func encode(_ value: Int) throws {
        storage.set(.int(value))
    }

    mutating func encode(_ value: Int8) throws {
        storage.set(.int(Int(value)))
    }

    mutating func encode(_ value: Int16) throws {
        storage.set(.int(Int(value)))
    }

    mutating func encode(_ value: Int32) throws {
        storage.set(.int(Int(value)))
    }

    mutating func encode(_ value: Int64) throws {
        guard let value = Int(exactly: value) else {
            throw unsupportedInteger("Int64")
        }
        storage.set(.int(value))
    }

    mutating func encode(_ value: UInt) throws {
        guard let value = Int(exactly: value) else {
            throw unsupportedInteger("UInt")
        }
        storage.set(.int(value))
    }

    mutating func encode(_ value: UInt8) throws {
        storage.set(.int(Int(value)))
    }

    mutating func encode(_ value: UInt16) throws {
        storage.set(.int(Int(value)))
    }

    mutating func encode(_ value: UInt32) throws {
        guard let value = Int(exactly: value) else {
            throw unsupportedInteger("UInt32")
        }
        storage.set(.int(value))
    }

    mutating func encode(_ value: UInt64) throws {
        guard let value = Int(exactly: value) else {
            throw unsupportedInteger("UInt64")
        }
        storage.set(.int(value))
    }

    mutating func encode(_ value: some Encodable) throws {
        try value.encode(to: PureYAML.Encoding.Encoder(
            codingPath: codingPath,
            userInfo: userInfo,
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

struct UnsupportedKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [any CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]

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
            userInfo: userInfo,
        ))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
        UnsupportedUnkeyedEncodingContainer(
            codingPath: codingPath + [key],
            userInfo: userInfo,
        )
    }

    mutating func superEncoder() -> any Swift.Encoder {
        PureYAML.Encoding.Encoder(codingPath: codingPath, userInfo: userInfo)
    }

    mutating func superEncoder(forKey key: Key) -> any Swift.Encoder {
        PureYAML.Encoding.Encoder(codingPath: codingPath + [key], userInfo: userInfo)
    }

    private func unsupported(_ key: Key) -> PureYAML.Encoding.Error {
        .unsupportedContainer(
            kind: "keyed",
            path: PureYAML.Validation.Path(codingPath: codingPath + [key]),
        )
    }
}
