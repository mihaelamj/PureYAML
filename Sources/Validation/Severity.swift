public extension PureYAML.Validation {
    /// Severity of a validation issue.
    enum Severity: Equatable, Sendable, CustomStringConvertible {
        case error
        case warning

        public var description: String {
            switch self {
            case .error:
                "error"
            case .warning:
                "warning"
            }
        }
    }
}
