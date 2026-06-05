public extension PureYAML.Emitting {
    /// Block-style YAML serializer for ``PureYAML/Model/Value``.
    struct Dumper: Sendable {
        public init() {}

        public func dump(_ value: PureYAML.Model.Value) -> String {
            render(value, indent: 0).joined(separator: "\n") + "\n"
        }
    }
}

extension PureYAML.Emitting.Dumper {
    func render(
        _ value: PureYAML.Model.Value,
        indent: Int,
    ) -> [String] {
        switch value {
        case let .mapping(mapping):
            renderMapping(mapping, indent: indent)
        case let .sequence(values):
            renderSequence(values, indent: indent)
        default:
            [String(repeating: " ", count: indent) + renderScalar(value)]
        }
    }

    func renderMapping(
        _ mapping: PureYAML.Model.Mapping,
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        return mapping.pairs.flatMap { pair in
            switch pair.value {
            case .mapping, .sequence:
                [prefix + escapeKey(pair.key) + ":"] + render(pair.value, indent: indent + 2)
            default:
                [prefix + escapeKey(pair.key) + ": " + renderScalar(pair.value)]
            }
        }
    }

    func renderSequence(
        _ values: [PureYAML.Model.Value],
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        return values.flatMap { value in
            switch value {
            case .mapping, .sequence:
                [prefix + "-"] + render(value, indent: indent + 2)
            default:
                [prefix + "- " + renderScalar(value)]
            }
        }
    }

    func renderScalar(_ value: PureYAML.Model.Value) -> String {
        switch value {
        case .null:
            "null"
        case let .bool(value):
            value ? "true" : "false"
        case let .int(value):
            String(value)
        case let .double(value):
            String(value)
        case let .string(value):
            quote(value)
        case .sequence, .mapping:
            ""
        }
    }

    func escapeKey(_ key: String) -> String {
        if key.isEmpty || key.contains(":") || key.contains("#") || key.contains("\n") {
            return quote(key)
        }
        return key
    }

    func quote(_ value: String) -> String {
        var output = "\""
        for character in value {
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
