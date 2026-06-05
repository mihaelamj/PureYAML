public extension PureYAML.Tagged {
    /// Context passed to a tagged-node validation rule.
    struct Context: Sendable {
        public var root: Node
        public var subject: Node
        public var path: PureYAML.Validation.Path

        public init(
            root: Node,
            subject: Node,
            path: PureYAML.Validation.Path,
        ) {
            self.root = root
            self.subject = subject
            self.path = path
        }
    }
}
