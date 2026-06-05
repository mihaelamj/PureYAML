public extension PureYAML.Stream {
    /// Validation issue with the document index preserved.
    struct Issue: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        public var documentIndex: Int
        public var issue: PureYAML.Validation.Issue

        public init(
            documentIndex: Int,
            issue: PureYAML.Validation.Issue,
        ) {
            self.documentIndex = documentIndex
            self.issue = issue
        }

        public var description: String {
            "document[\(documentIndex)]: \(issue.description)"
        }
    }
}
