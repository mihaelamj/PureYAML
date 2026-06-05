extension PureYAML.Model.Value {
    var flowDescription: String {
        switch self {
        case .null:
            "null"
        case let .bool(value):
            value ? "true" : "false"
        case let .double(value):
            String(value)
        case let .int(value):
            String(value)
        case let .mapping(value):
            value.flowDescription
        case let .sequence(value):
            value.flowDescription
        case let .string(value):
            value.quotedFlowDescription
        }
    }
}

extension PureYAML.Model.Mapping {
    var flowDescription: String {
        let pairs = pairs
            .map { pair in
                "\(pair.keyNode.flowDescription): \(pair.value.flowDescription)"
            }
            .joined(separator: ", ")
        return "{\(pairs)}"
    }
}

extension PureYAML.Model.Key {
    var flowDescription: String {
        switch self {
        case let .mapping(value):
            value.flowDescription
        case let .sequence(value):
            value.flowDescription
        case let .string(value):
            value.quotedFlowDescription
        }
    }
}

extension [PureYAML.Model.Value] {
    var flowDescription: String {
        "[\(map(\.flowDescription).joined(separator: ", "))]"
    }
}

private extension String {
    var quotedFlowDescription: String {
        var output = "\""
        for character in self {
            switch character {
            case "\"":
                output += "\\\""
            case "\\":
                output += "\\\\"
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
        output += "\""
        return output
    }
}
