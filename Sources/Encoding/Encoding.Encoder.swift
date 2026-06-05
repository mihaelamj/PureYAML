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
            storage.set(.sequence([]))
            return UnkeyedEncodingContainerImpl(
                storage: storage,
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
        private let parentIndex: Int?

        init(
            parent: Storage? = nil,
            parentKey: String? = nil,
            parentIndex: Int? = nil,
        ) {
            self.parent = parent
            self.parentKey = parentKey
            self.parentIndex = parentIndex
        }

        func set(_ value: PureYAML.Model.Value) {
            self.value = value
            if let parent, let parentKey {
                parent.set(value, forKey: parentKey)
            } else if let parent, let parentIndex {
                parent.set(value, atIndex: parentIndex)
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

        func append(_ value: PureYAML.Model.Value) {
            var values: [PureYAML.Model.Value] = if case let .sequence(existing) = self.value {
                existing
            } else {
                []
            }

            values.append(value)
            set(.sequence(values))
        }

        func set(
            _ value: PureYAML.Model.Value,
            atIndex index: Int,
        ) {
            var values: [PureYAML.Model.Value] = if case let .sequence(existing) = self.value {
                existing
            } else {
                []
            }

            if index == values.count {
                values.append(value)
            } else if index < values.count {
                values[index] = value
            }
            set(.sequence(values))
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
