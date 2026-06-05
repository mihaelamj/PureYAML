public extension PureYAML.Model {
    /// Ordered YAML mapping.
    struct Mapping: Equatable, Hashable, Sendable {
        public var pairs: [Pair]

        public init(_ pairs: [Pair] = []) {
            self.pairs = pairs
        }

        public subscript(key: String) -> Value? {
            pairs.first { $0.keyNode == .string(key) }?.value
        }

        public subscript(keyNode: Key) -> Value? {
            pairs.first { $0.keyNode == keyNode }?.value
        }
    }
}
