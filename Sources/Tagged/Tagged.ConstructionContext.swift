public extension PureYAML.Tagged {
    /// Context passed to a tagged-node construction handler.
    struct ConstructionContext<Output>: Sendable {
        public var root: Node
        public var subject: Node
        public var path: PureYAML.Validation.Path

        let constructValue: @Sendable (Node, PureYAML.Validation.Path) throws -> Output

        init(
            root: Node,
            subject: Node,
            path: PureYAML.Validation.Path,
            constructValue: @escaping @Sendable (Node, PureYAML.Validation.Path) throws -> Output,
        ) {
            self.root = root
            self.subject = subject
            self.path = path
            self.constructValue = constructValue
        }

        /// Constructs another node with the same constructor policy.
        public func construct(
            _ node: Node,
            at path: PureYAML.Validation.Path,
        ) throws -> Output {
            try constructValue(node, path)
        }
    }
}
