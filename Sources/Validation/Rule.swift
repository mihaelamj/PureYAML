public extension PureYAML.Validation {
    /// A validation rule that can report zero or more path-aware issues.
    struct Rule: Sendable {
        public var description: String
        public var check: @Sendable (Context) -> [Issue]

        public init(
            description: String,
            check: @escaping @Sendable (Context) -> [Issue],
        ) {
            self.description = description
            self.check = check
        }

        public func apply(_ context: Context) -> [Issue] {
            check(context)
        }
    }
}
