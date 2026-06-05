public extension PureYAML.Model {
    /// One key-value entry in an ordered YAML mapping.
    struct Pair: Equatable, Hashable, Sendable {
        public var keyNode: Key
        public var value: Value

        public var key: String {
            get { keyNode.stringValue ?? keyNode.description }
            set { keyNode = .string(newValue) }
        }

        public init(
            key: String,
            value: Value,
        ) {
            keyNode = .string(key)
            self.value = value
        }

        public init(
            keyNode: Key,
            value: Value,
        ) {
            self.keyNode = keyNode
            self.value = value
        }
    }
}
