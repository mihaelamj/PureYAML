public extension PureYAML.Stream {
    /// Collected validation issues across a YAML stream.
    struct Result: Equatable, Sendable {
        public var issues: [Issue]

        public init(_ issues: [Issue] = []) {
            self.issues = issues
        }

        public var errors: [Issue] {
            issues.filter { $0.issue.severity == .error }
        }

        public var warnings: [Issue] {
            issues.filter { $0.issue.severity == .warning }
        }

        public var isValid: Bool {
            errors.isEmpty
        }
    }
}
