public extension PureYAML.Tagged {
    enum NodeKind: String, Equatable, Sendable, CustomStringConvertible {
        case scalar
        case sequence
        case mapping

        public var description: String {
            rawValue
        }
    }

    /// YAML node tree that preserves explicit source tags.
    enum Node: Equatable, Sendable {
        case scalar(Scalar)
        case sequence(Sequence)
        case mapping(Mapping)

        public var tag: Tag? {
            switch self {
            case let .mapping(mapping):
                mapping.tag
            case let .scalar(scalar):
                scalar.tag
            case let .sequence(sequence):
                sequence.tag
            }
        }

        public var kind: NodeKind {
            switch self {
            case .mapping:
                .mapping
            case .scalar:
                .scalar
            case .sequence:
                .sequence
            }
        }
    }

    struct Scalar: Equatable, Sendable {
        public var rawValue: String
        public var value: PureYAML.Model.Value
        public var tag: Tag?

        public init(
            rawValue: String,
            value: PureYAML.Model.Value,
            tag: Tag? = nil,
        ) {
            self.rawValue = rawValue
            self.value = value
            self.tag = tag
        }
    }

    struct Sequence: Equatable, Sendable {
        public var values: [Node]
        public var tag: Tag?

        public init(
            values: [Node],
            tag: Tag? = nil,
        ) {
            self.values = values
            self.tag = tag
        }
    }

    struct Mapping: Equatable, Sendable {
        public var pairs: [Pair]
        public var tag: Tag?

        public init(
            pairs: [Pair],
            tag: Tag? = nil,
        ) {
            self.pairs = pairs
            self.tag = tag
        }

        public subscript(_ key: String) -> Node? {
            pairs.first { $0.key == key }?.value
        }
    }

    struct Pair: Equatable, Sendable {
        public var key: String
        public var keyTag: Tag?
        public var value: Node

        public init(
            key: String,
            keyTag: Tag? = nil,
            value: Node,
        ) {
            self.key = key
            self.keyTag = keyTag
            self.value = value
        }
    }
}
