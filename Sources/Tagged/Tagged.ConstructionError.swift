public extension PureYAML.Tagged {
    /// Error returned when a tagged node cannot be constructed by a caller policy.
    enum ConstructionError: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        case noConstructor(
            tag: Tag?,
            kind: NodeKind,
            path: PureYAML.Validation.Path,
        )
        case kindMismatch(
            tag: Tag,
            expected: [NodeKind],
            actual: NodeKind,
            path: PureYAML.Validation.Path,
        )

        public var description: String {
            switch self {
            case let .kindMismatch(tag, expected, actual, path):
                "Constructor for tag '\(tag)' expects \(expected.kindListDescription), found \(actual) at \(path)"
            case let .noConstructor(.some(tag), kind, path):
                "No constructor for tag '\(tag)' on \(kind) at \(path)"
            case let .noConstructor(nil, kind, path):
                "No constructor for untagged \(kind) at \(path)"
            }
        }
    }
}

private extension [PureYAML.Tagged.NodeKind] {
    var kindListDescription: String {
        switch count {
        case 0:
            "no node kind"
        case 1:
            self[0].description
        case 2:
            "\(self[0]) or \(self[1])"
        default:
            "\(dropLast().map(\.description).joined(separator: ", ")), or \(last?.description ?? "unknown")"
        }
    }
}
