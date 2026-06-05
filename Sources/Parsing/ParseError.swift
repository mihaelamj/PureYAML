public extension PureYAML.Parsing {
    /// Parser error with source line information when available.
    enum ParseError: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        case emptyDocument
        case tabIndentation(line: Int)
        case unexpectedIndentation(line: Int)
        case mixedCollectionStyles(line: Int)
        case expectedMappingKey(line: Int)
        case expectedAnchorName(line: Int)
        case expectedAliasName(line: Int)
        case expectedNode(line: Int, column: Int)
        case expectedScalarKey(line: Int, column: Int)
        case unterminatedTag(line: Int)
        case unterminatedQuotedString(line: Int)
        case undefinedAlias(anchor: String, line: Int, column: Int)
        case unexpectedEvent(expected: String, actual: String, line: Int, column: Int)
        case unexpectedToken(expected: String, actual: String, line: Int, column: Int)

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
            case let .expectedAnchorName(line):
                "expected an anchor name at line \(line)"
            case let .expectedAliasName(line):
                "expected an alias name at line \(line)"
            case let .expectedNode(line, column):
                "expected a YAML node at line \(line), column \(column)"
            case let .expectedScalarKey(line, column):
                "expected a scalar mapping key at line \(line), column \(column)"
            case let .unterminatedTag(line):
                "unterminated tag at line \(line)"
            case let .unterminatedQuotedString(line):
                "unterminated quoted string at line \(line)"
            case let .undefinedAlias(anchor, line, column):
                "undefined alias '\(anchor)' at line \(line), column \(column)"
            case let .unexpectedEvent(expected, actual, line, column):
                "expected \(expected) at line \(line), column \(column), found \(actual)"
            case let .unexpectedToken(expected, actual, line, column):
                "expected \(expected) at line \(line), column \(column), found \(actual)"
            }
        }
    }
}
