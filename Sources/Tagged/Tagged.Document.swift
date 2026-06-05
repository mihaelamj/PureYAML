public extension PureYAML.Tagged {
    /// One parsed YAML stream document with its zero-based stream index.
    struct Document: Equatable, Sendable {
        public var index: Int
        public var node: Node

        public init(
            index: Int,
            node: Node,
        ) {
            self.index = index
            self.node = node
        }
    }
}
