public extension PureYAML.Validation {
    /// A validation rule that can report zero or more path-aware issues.
    struct Rule: Sendable {
        public var description: String
        public var predicate: @Sendable (Context) -> Bool
        public var check: @Sendable (Context) -> [Issue]

        public init(
            description: String,
            check: @escaping @Sendable (Context) -> [Issue],
            when predicate: @escaping @Sendable (Context) -> Bool = { _ in true },
        ) {
            self.description = description
            self.predicate = predicate
            self.check = check
        }

        public init(
            description: String,
            severity: Severity = .error,
            check: @escaping @Sendable (Context) -> Bool,
            when predicate: @escaping @Sendable (Context) -> Bool = { _ in true },
        ) {
            self.init(
                description: description,
                check: { context in
                    check(context)
                        ? []
                        : [
                            Issue(
                                severity: severity,
                                reason: "Failed to satisfy: \(description)",
                                path: context.path,
                            ),
                        ]
                },
                when: predicate,
            )
        }

        public func apply(_ context: Context) -> [Issue] {
            guard predicate(context) else {
                return []
            }
            return check(context)
        }
    }
}
