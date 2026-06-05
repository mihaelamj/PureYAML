public extension PureYAML.Decoding {
    /// Scalar typed decoder backed by a ``PureYAML/Model/Value``.
    struct Decoder: Swift.Decoder {
        public let value: PureYAML.Model.Value
        public let codingPath: [any CodingKey]
        public let userInfo: [CodingUserInfoKey: Any]

        public init(
            value: PureYAML.Model.Value,
            codingPath: [any CodingKey] = [],
            userInfo: [CodingUserInfoKey: Any] = [:],
        ) {
            self.value = value
            self.codingPath = codingPath
            self.userInfo = userInfo
        }

        public func container<Key: CodingKey>(
            keyedBy _: Key.Type,
        ) throws -> KeyedDecodingContainer<Key> {
            throw Error.unsupportedContainer(
                kind: "keyed",
                path: PureYAML.Validation.Path(codingPath: codingPath),
            )
        }

        public func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
            throw Error.unsupportedContainer(
                kind: "unkeyed",
                path: PureYAML.Validation.Path(codingPath: codingPath),
            )
        }

        public func singleValueContainer() throws -> any SingleValueDecodingContainer {
            SingleValueContainer(
                value: value,
                codingPath: codingPath,
                userInfo: userInfo,
            )
        }
    }
}

private struct SingleValueContainer: SingleValueDecodingContainer {
    let value: PureYAML.Model.Value
    let codingPath: [any CodingKey]
    let userInfo: [CodingUserInfoKey: Any]

    func decodeNil() -> Bool {
        value == .null
    }

    func decode(_: Bool.Type) throws -> Bool {
        guard case let .bool(value) = value else {
            throw mismatch("Bool")
        }
        return value
    }

    func decode(_: String.Type) throws -> String {
        guard case let .string(value) = value else {
            throw mismatch("String")
        }
        return value
    }

    func decode(_: Double.Type) throws -> Double {
        switch value {
        case let .double(value):
            return value
        case let .int(value):
            return Double(value)
        case .null, .bool, .string, .sequence, .mapping:
            throw mismatch("Double")
        }
    }

    func decode(_: Float.Type) throws -> Float {
        try Float(decode(Double.self))
    }

    func decode(_: Int.Type) throws -> Int {
        guard case let .int(value) = value else {
            throw mismatch("Int")
        }
        return value
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        try decodeInteger(type)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        try decodeInteger(type)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        try decodeInteger(type)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        try decodeInteger(type)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        try decodeUnsignedInteger(type)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try decodeUnsignedInteger(type)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try decodeUnsignedInteger(type)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try decodeUnsignedInteger(type)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try decodeUnsignedInteger(type)
    }

    func decode<Value: Decodable>(_: Value.Type) throws -> Value {
        try Value(from: PureYAML.Decoding.Decoder(
            value: value,
            codingPath: codingPath,
            userInfo: userInfo,
        ))
    }

    private func decodeInteger<Integer: FixedWidthInteger>(
        _: Integer.Type,
    ) throws -> Integer {
        let value = try decode(Int.self)
        guard let converted = Integer(exactly: value) else {
            throw integerOutOfRange(String(describing: Integer.self))
        }
        return converted
    }

    private func decodeUnsignedInteger<Integer: FixedWidthInteger>(
        _: Integer.Type,
    ) throws -> Integer {
        let value = try decode(Int.self)
        guard let converted = Integer(exactly: value) else {
            throw integerOutOfRange(String(describing: Integer.self))
        }
        return converted
    }

    private func mismatch(_ expected: String) -> PureYAML.Decoding.Error {
        .typeMismatch(
            expected: expected,
            actual: value.kindDescription,
            path: PureYAML.Validation.Path(codingPath: codingPath),
        )
    }

    private func integerOutOfRange(_ type: String) -> PureYAML.Decoding.Error {
        .integerOutOfRange(
            type: type,
            path: PureYAML.Validation.Path(codingPath: codingPath),
        )
    }
}
