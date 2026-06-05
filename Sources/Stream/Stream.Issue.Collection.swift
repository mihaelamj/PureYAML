public extension PureYAML.Stream.Issue {
    /// Error thrown when stream validation reports failing issues.
    struct Collection: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        public var issues: [PureYAML.Stream.Issue]

        public init(_ issues: [PureYAML.Stream.Issue]) {
            self.issues = issues
        }

        public var description: String {
            issues.map(\.description).joined(separator: "\n")
        }
    }
}
