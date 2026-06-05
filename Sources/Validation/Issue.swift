public extension PureYAML.Validation {
    /// Path-aware validation issue.
    struct Issue: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        public var severity: Severity
        public var reason: String
        public var path: Path

        public init(
            severity: Severity,
            reason: String,
            path: Path = .root,
        ) {
            self.severity = severity
            self.reason = reason
            self.path = path
        }

        public var description: String {
            let location = path.isRoot ? "root" : path.description
            return "\(severity.description): \(reason) at \(location)"
        }
    }
}
