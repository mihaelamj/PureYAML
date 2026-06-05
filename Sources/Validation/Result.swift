public extension PureYAML.Validation {
    /// Collected validation issues.
    struct Result: Equatable, Sendable {
        public var issues: [Issue]

        public init(_ issues: [Issue] = []) {
            self.issues = issues
        }

        public var errors: [Issue] {
            issues.filter { $0.severity == .error }
        }

        public var warnings: [Issue] {
            issues.filter { $0.severity == .warning }
        }

        public var isValid: Bool {
            errors.isEmpty
        }
    }
}
