extension PureYAML.Parsing {
    struct Token: Equatable, CustomStringConvertible {
        var kind: TokenKind
        var mark: Mark
        var endMark: Mark

        var description: String {
            "\(kind) @\(mark)..\(endMark)"
        }
    }
}

extension PureYAML.Parsing {
    enum TokenKind: Equatable {
        case streamStart
        case streamEnd
        case documentStart
        case documentEnd
        case indent(width: Int)
        case dedent(width: Int)
        case blockEntry
        case mappingKey
        case mappingValue
        case flowSequenceStart
        case flowSequenceEnd
        case flowMappingStart
        case flowMappingEnd
        case flowEntry
        case scalar(value: String, style: ScalarStyle)
        case blockScalarHeader(style: BlockScalarStyle, chomping: BlockScalarChomping)
        case anchor(String)
        case alias(String)
        case tag(String)
        case comment(String)
    }
}

extension PureYAML.Parsing.TokenKind: CustomStringConvertible {
    var description: String {
        switch self {
        case .streamStart:
            "streamStart"
        case .streamEnd:
            "streamEnd"
        case .documentStart:
            "documentStart"
        case .documentEnd:
            "documentEnd"
        case let .indent(width):
            "indent width=\(width)"
        case let .dedent(width):
            "dedent width=\(width)"
        case .blockEntry:
            "blockEntry"
        case .mappingKey:
            "mappingKey"
        case .mappingValue:
            "mappingValue"
        case .flowSequenceStart:
            "flowSequenceStart"
        case .flowSequenceEnd:
            "flowSequenceEnd"
        case .flowMappingStart:
            "flowMappingStart"
        case .flowMappingEnd:
            "flowMappingEnd"
        case .flowEntry:
            "flowEntry"
        case let .scalar(value, style):
            "scalar value=\"\(escape(value))\" style=\(style)"
        case let .blockScalarHeader(style, chomping):
            if chomping == .clip {
                "blockScalarHeader style=\(style)"
            } else {
                "blockScalarHeader style=\(style) chomping=\(chomping)"
            }
        case let .anchor(value):
            "anchor name=\(value)"
        case let .alias(value):
            "alias name=\(value)"
        case let .tag(value):
            "tag value=\(value)"
        case let .comment(value):
            "comment value=\"\(escape(value))\""
        }
    }

    private func escape(_ value: String) -> String {
        var output = ""
        for character in value {
            switch character {
            case "\\":
                output += "\\\\"
            case "\"":
                output += "\\\""
            case "\n":
                output += "\\n"
            case "\r":
                output += "\\r"
            case "\t":
                output += "\\t"
            default:
                output.append(character)
            }
        }
        return output
    }
}
