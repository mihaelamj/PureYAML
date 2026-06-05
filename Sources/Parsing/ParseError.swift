public extension PureYAML.Parsing {
    /// Parser error with source line information when available.
    enum ParseError: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        case emptyDocument
        case tabIndentation(line: Int)
        case unexpectedIndentation(line: Int)
        case mixedCollectionStyles(line: Int)
        case expectedMappingKey(line: Int)
        case unterminatedQuotedString(line: Int)

        public var description: String {
            switch self {
            case .emptyDocument:
                "document is empty"
            case let .tabIndentation(line):
                "tabs are not allowed for indentation at line \(line)"
            case let .unexpectedIndentation(line):
                "unexpected indentation at line \(line)"
            case let .mixedCollectionStyles(line):
                "mapping and sequence entries are mixed at line \(line)"
            case let .expectedMappingKey(line):
                "expected a mapping key at line \(line)"
            case let .unterminatedQuotedString(line):
                "unterminated quoted string at line \(line)"
            }
        }
    }
}
