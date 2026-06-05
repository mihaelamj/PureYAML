public extension PureYAML.Model {
    /// Ordered YAML mapping.
    struct Mapping: Equatable, Sendable {
        public var pairs: [Pair]

        public init(_ pairs: [Pair] = []) {
            self.pairs = pairs
        }

        public subscript(key: String) -> Value? {
            pairs.first { $0.key == key }?.value
        }
    }
}
