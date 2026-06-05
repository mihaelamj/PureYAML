public extension PureYAML.Emitting {
    /// Block-style YAML serializer for ``PureYAML/Model/Value``.
    struct Dumper: Sendable {
        public var options: Options

        public init(options: Options = .default) {
            self.options = options
        }

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
            renderString(value)
        case .sequence, .mapping:
            ""
        }
    }

    func renderString(_ value: String) -> String {
        switch options.scalarStyle {
        case .quoted:
            quote(value)
        case .plainWhenSafe:
            canRenderPlainString(value) ? value : quote(value)
        }
    }

    func canRenderPlainString(_ value: String) -> Bool {
        guard !value.isEmpty else {
            return false
        }
        guard value.first?.isWhitespace == false, value.last?.isWhitespace == false else {
            return false
        }
        guard !value.contains("\n"), !value.contains("\r"), !value.contains("\t") else {
            return false
        }
        guard !isReservedPlainScalar(value), !isNumberLikePlainScalar(value) else {
            return false
        }
        guard let first = value.first, !isPlainScalarIndicator(first) else {
            return false
        }
        return !containsColonSpace(value) && !value.contains("#")
    }

    func containsColonSpace(_ value: String) -> Bool {
        var previousWasColon = false
        for character in value {
            if previousWasColon, character == " " {
                return true
            }
            previousWasColon = character == ":"
        }
        return false
    }

    func isReservedPlainScalar(_ value: String) -> Bool {
        switch value {
        case "~", "null", "Null", "NULL", "true", "True", "TRUE", "false", "False", "FALSE":
            true
        default:
            false
        }
    }

    func isNumberLikePlainScalar(_ value: String) -> Bool {
        if Int(value) != nil, !value.contains(".") {
            return true
        }
        if value.contains(".") || value.contains("e") || value.contains("E") {
            return Double(value) != nil
        }
        return false
    }

    func isPlainScalarIndicator(_ character: Character) -> Bool {
        "-?:,[]{}#&*!|>'\"%@`".contains(character)
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
