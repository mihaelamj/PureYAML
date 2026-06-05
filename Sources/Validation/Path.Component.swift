public extension PureYAML.Validation.Path {
    /// One path step inside a YAML document.
    enum Component: Equatable, Sendable, CustomStringConvertible {
        case key(String)
        case complexKey(PureYAML.Model.Key)
        case index(Int)

        public var description: String {
            switch self {
            case let .complexKey(key):
                "[?\(key.flowDescription)]"
            case let .key(key):
                key.isDotPathSafeKey ? ".\(key)" : "[\"\(key.escapedPathKey)\"]"
            case let .index(index):
                "[\(index)]"
            }
        }
    }
}

private extension String {
    var isDotPathSafeKey: Bool {
        guard let first = unicodeScalars.first,
              first.isPathIdentifierStart
        else {
            return false
        }

        return unicodeScalars.dropFirst().allSatisfy(\.isPathIdentifierBody)
    }

    var escapedPathKey: String {
        reduce(into: "") { result, character in
            switch character {
            case "\\":
                result += "\\\\"
            case "\"":
                result += "\\\""
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            case "\t":
                result += "\\t"
            default:
                result.append(character)
            }
        }
    }
}

private extension Unicode.Scalar {
    var isPathIdentifierStart: Bool {
        self == "_" || ("A" ... "Z").contains(self) || ("a" ... "z").contains(self)
    }

    var isPathIdentifierBody: Bool {
        isPathIdentifierStart || ("0" ... "9").contains(self)
    }
}
