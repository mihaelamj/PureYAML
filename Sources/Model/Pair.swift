public extension PureYAML.Model {
    /// One key-value entry in an ordered YAML mapping.
    struct Pair: Equatable, Sendable {
        public var key: String
        public var value: Value

        public init(
            key: String,
            value: Value,
        ) {
            self.key = key
            self.value = value
        }
    }
}
