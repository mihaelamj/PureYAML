public extension PureYAML.Encoding {
    /// Error reported by typed YAML encoding.
    enum Error: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        case unsupportedContainer(
            kind: String,
            path: PureYAML.Validation.Path,
        )
        case integerOutOfRange(
            type: String,
            path: PureYAML.Validation.Path,
        )
        case noValueEncoded(path: PureYAML.Validation.Path)

        public var description: String {
            switch self {
            case let .unsupportedContainer(kind, path):
                "Unsupported \(kind) encoding container at \(path)"
            case let .integerOutOfRange(type, path):
                "\(type) value is outside PureYAML integer range at \(path)"
            case let .noValueEncoded(path):
                "No YAML value was encoded at \(path)"
            }
        }
    }
}
