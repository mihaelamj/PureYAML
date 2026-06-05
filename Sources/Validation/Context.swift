public extension PureYAML.Validation {
    /// Context passed to a validation rule.
    struct Context: Sendable {
        public var root: PureYAML.Model.Value
        public var subject: PureYAML.Model.Value
        public var path: Path

        public init(
            root: PureYAML.Model.Value,
            subject: PureYAML.Model.Value,
            path: Path,
        ) {
            self.root = root
            self.subject = subject
            self.path = path
        }
    }
}
