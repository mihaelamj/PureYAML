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
            renderScalarNode(value, indent: indent)
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
                renderMappingScalarPair(pair, indent: indent)
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
                renderSequenceScalarItem(value, indent: indent)
            }
        }
    }

    func renderScalarNode(
        _ value: PureYAML.Model.Value,
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        if let lines = renderLiteralBlockString(value, contentIndent: indent + 2) {
            return [prefix + lines.header] + lines.content
        }
        return [prefix + renderScalar(value)]
    }

    func renderMappingScalarPair(
        _ pair: PureYAML.Model.Pair,
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        let key = escapeKey(pair.key)
        if let lines = renderLiteralBlockString(pair.value, contentIndent: indent + 2) {
            return [prefix + key + ": " + lines.header] + lines.content
        }
        return [prefix + key + ": " + renderScalar(pair.value)]
    }

    func renderSequenceScalarItem(
        _ value: PureYAML.Model.Value,
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        if let lines = renderLiteralBlockString(value, contentIndent: indent + 2) {
            return [prefix + "- " + lines.header] + lines.content
        }
        return [prefix + "- " + renderScalar(value)]
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
        case .literalBlockWhenMultiline:
            quote(value)
        }
    }

    func renderLiteralBlockString(
        _ value: PureYAML.Model.Value,
        contentIndent: Int,
    ) -> (header: String, content: [String])? {
        guard
            case let .string(string) = value,
            options.scalarStyle == .literalBlockWhenMultiline,
            canRenderLiteralBlockString(string)
        else {
            return nil
        }

        let keepsTrailingNewline = string.hasSuffix("\n")
        let header = keepsTrailingNewline ? "|" : "|-"
        let contentSource = keepsTrailingNewline ? String(string.dropLast()) : string
        let prefix = String(repeating: " ", count: contentIndent)
        let content = contentSource.split(separator: "\n", omittingEmptySubsequences: false)
            .map { prefix + String($0) }
        return (header, content)
    }

    func canRenderLiteralBlockString(_ value: String) -> Bool {
        guard value.contains("\n"), !value.contains("\r"), !value.contains("\t") else {
            return false
        }

        let contentSource = value.hasSuffix("\n") ? String(value.dropLast()) : value
        guard !contentSource.isEmpty else {
            return false
        }

        return contentSource
            .split(separator: "\n", omittingEmptySubsequences: false)
            .allSatisfy(canRenderLiteralBlockLine)
    }

    func canRenderLiteralBlockLine(_ line: Substring) -> Bool {
        guard !line.isEmpty, line.first?.isWhitespace == false, line.last?.isWhitespace == false else {
            return false
        }
        guard !line.contains("#"), !containsColonSpace(String(line)) else {
            return false
        }
        guard let first = line.first else {
            return false
        }
        return !isPlainScalarIndicator(first)
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
