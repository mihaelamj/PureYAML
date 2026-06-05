extension PureYAML.Parsing {
    enum Event: Equatable, CustomStringConvertible {
        case streamStart(mark: Mark)
        case streamEnd(mark: Mark)
        case documentStart(mark: Mark)
        case documentEnd(mark: Mark)
        case sequenceStart(anchor: String?, tag: String?, style: CollectionStyle, mark: Mark)
        case sequenceEnd(mark: Mark)
        case mappingStart(anchor: String?, tag: String?, style: CollectionStyle, mark: Mark)
        case mappingEnd(mark: Mark)
        case scalar(value: String, anchor: String?, tag: String?, style: ScalarStyle, mark: Mark)
        case alias(anchor: String, mark: Mark)

        var description: String {
            switch self {
            case let .streamStart(mark):
                "streamStart @\(mark)"
            case let .streamEnd(mark):
                "streamEnd @\(mark)"
            case let .documentStart(mark):
                "documentStart @\(mark)"
            case let .documentEnd(mark):
                "documentEnd @\(mark)"
            case let .sequenceStart(anchor, tag, style, mark):
                "sequenceStart anchor=\(describe(anchor)) tag=\(describe(tag)) style=\(style) @\(mark)"
            case let .sequenceEnd(mark):
                "sequenceEnd @\(mark)"
            case let .mappingStart(anchor, tag, style, mark):
                "mappingStart anchor=\(describe(anchor)) tag=\(describe(tag)) style=\(style) @\(mark)"
            case let .mappingEnd(mark):
                "mappingEnd @\(mark)"
            case let .scalar(value, anchor, tag, style, mark):
                "scalar value=\"\(escape(value))\" anchor=\(describe(anchor)) tag=\(describe(tag)) style=\(style) @\(mark)"
            case let .alias(anchor, mark):
                "alias anchor=\(anchor) @\(mark)"
            }
        }
    }
}

extension PureYAML.Parsing.Event {
    var isMappingEnd: Bool {
        if case .mappingEnd = self {
            return true
        }
        return false
    }

    var isSequenceEnd: Bool {
        if case .sequenceEnd = self {
            return true
        }
        return false
    }

    var mark: PureYAML.Parsing.Mark {
        switch self {
        case let .alias(_, mark),
             let .documentEnd(mark),
             let .documentStart(mark),
             let .mappingEnd(mark),
             let .mappingStart(_, _, _, mark),
             let .scalar(_, _, _, _, mark),
             let .sequenceEnd(mark),
             let .sequenceStart(_, _, _, mark),
             let .streamEnd(mark),
             let .streamStart(mark):
            mark
        }
    }

    private func describe(_ value: String?) -> String {
        value ?? "-"
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
