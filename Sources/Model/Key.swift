public extension PureYAML.Model {
    /// YAML mapping key node.
    enum Key: Equatable, Hashable, Sendable, CustomStringConvertible {
        case string(String)
        case sequence([Value])
        case mapping(Mapping)

        public init(value: Value) {
            switch value {
            case .null:
                self = .string("null")
            case let .bool(value):
                self = .string(value ? "true" : "false")
            case let .double(value):
                self = .string(String(value))
            case let .int(value):
                self = .string(String(value))
            case let .mapping(value):
                self = .mapping(value)
            case let .sequence(value):
                self = .sequence(value)
            case let .string(value):
                self = .string(value)
            }
        }

        public var stringValue: String? {
            guard case let .string(value) = self else {
                return nil
            }
            return value
        }

        public var value: Value {
            switch self {
            case let .mapping(value):
                .mapping(value)
            case let .sequence(value):
                .sequence(value)
            case let .string(value):
                .string(value)
            }
        }

        public var description: String {
            switch self {
            case let .mapping(value):
                value.flowDescription
            case let .sequence(value):
                value.flowDescription
            case let .string(value):
                value
            }
        }
    }
}
