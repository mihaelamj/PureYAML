public extension PureYAML.Decoding {
    /// Error reported by typed YAML decoding.
    enum Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        case typeMismatch(
            expected: String,
            actual: String,
            path: PureYAML.Validation.Path,
        )
        case integerOutOfRange(
            type: String,
            path: PureYAML.Validation.Path,
        )
        case keyNotFound(
            key: String,
            path: PureYAML.Validation.Path,
        )
        case valueNotFound(path: PureYAML.Validation.Path)

        public var description: String {
            switch self {
            case let .typeMismatch(expected, actual, path):
                "Expected \(expected) at \(path), found \(actual)"
            case let .integerOutOfRange(type, path):
                "\(type) value is outside PureYAML integer range at \(path)"
            case let .keyNotFound(key, path):
                "Missing required key '\(key)' at \(path)"
            case let .valueNotFound(path):
                "No YAML value found at \(path)"
            }
        }
    }
}
