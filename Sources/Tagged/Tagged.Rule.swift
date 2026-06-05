public extension PureYAML.Tagged {
    /// A validation rule for tag-preserving YAML nodes.
    struct Rule: Sendable {
        public let description: String
        public let predicate: @Sendable (Context) -> Bool
        public let check: @Sendable (Context) -> [PureYAML.Validation.Issue]

        public init(
            description: String,
            check: @escaping @Sendable (Context) -> [PureYAML.Validation.Issue],
            when predicate: @escaping @Sendable (Context) -> Bool = { _ in true },
        ) {
            self.description = description
            self.predicate = predicate
            self.check = check
        }

        public init(
            description: String,
            severity: PureYAML.Validation.Severity = .error,
            check: @escaping @Sendable (Context) -> Bool,
            when predicate: @escaping @Sendable (Context) -> Bool = { _ in true },
        ) {
            self.init(
                description: description,
                check: { context in
                    check(context)
                        ? []
                        : [
                            PureYAML.Validation.Issue(
                                severity: severity,
                                reason: "Failed to satisfy: \(description)",
                                path: context.path,
                            ),
                        ]
                },
                when: predicate,
            )
        }

        public func apply(_ context: Context) -> [PureYAML.Validation.Issue] {
            guard predicate(context) else {
                return []
            }
            return check(context)
        }
    }
}
