public extension PureYAML.Validation.Path {
    /// One path step inside a YAML document.
    enum Component: Equatable, Sendable, CustomStringConvertible {
        case key(String)
        case index(Int)

        public var description: String {
            switch self {
            case let .key(key):
                ".\(key)"
            case let .index(index):
                "[\(index)]"
            }
        }
    }
}
