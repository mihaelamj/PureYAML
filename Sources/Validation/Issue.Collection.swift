public extension PureYAML.Validation.Issue {
    /// Error thrown when validation reports failing issues.
    struct Collection: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        public var issues: [PureYAML.Validation.Issue]

        public init(_ issues: [PureYAML.Validation.Issue]) {
            self.issues = issues
        }

        public var description: String {
            issues.map(\.description).joined(separator: "\n")
        }
    }
}
