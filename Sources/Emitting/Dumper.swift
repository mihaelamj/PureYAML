public extension PureYAML.Emitting {
    /// Block-style YAML serializer for ``PureYAML/Model/Value``.
    struct Dumper: Sendable {
        public var options: Options

        public init(options: Options = .default) {
            self.options = options
        }

        public func dump(_ value: PureYAML.Model.Value) -> String {
            switch options.collectionStyle {
            case .block:
                render(value, indent: 0).joined(separator: "\n") + "\n"
            case .flow:
                renderFlowDocument(value)
            }
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

    func renderSequence(
        _ values: [PureYAML.Model.Value],
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        guard !values.isEmpty else {
            return [prefix + "[]"]
        }

        return values.flatMap { value in
            if let emptyCollection = renderEmptyCollectionLiteral(value) {
                return [prefix + "- " + emptyCollection]
            }

            switch value {
            case .mapping, .sequence:
                return [prefix + "-"] + render(value, indent: indent + 2)
            default:
                return renderSequenceScalarItem(value, indent: indent)
            }
        }
    }

    func renderFlowDocument(_ value: PureYAML.Model.Value) -> String {
        switch value {
        case .mapping, .sequence:
            renderFlow(value) + "\n"
        default:
            renderScalarNode(value, indent: 0).joined(separator: "\n") + "\n"
        }
    }

    func renderFlow(_ value: PureYAML.Model.Value) -> String {
        switch value {
        case let .mapping(mapping):
            renderFlowMapping(mapping)
        case let .sequence(values):
            renderFlowSequence(values)
        default:
            renderFlowScalar(value)
        }
    }

    func renderFlowSequence(_ values: [PureYAML.Model.Value]) -> String {
        let items = values
            .map(renderFlow)
            .joined(separator: ", ")
        return "[\(items)]"
    }

    func renderEmptyCollectionLiteral(_ value: PureYAML.Model.Value) -> String? {
        switch value {
        case let .mapping(mapping) where mapping.pairs.isEmpty:
            "{}"
        case let .sequence(values) where values.isEmpty:
            "[]"
        default:
            nil
        }
    }

    func renderFlowScalar(_ value: PureYAML.Model.Value) -> String {
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
            renderFlowString(value)
        case .sequence, .mapping:
            ""
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

    func renderFlowString(_ value: String) -> String {
        switch options.scalarStyle {
        case .plainWhenSafe:
            canRenderFlowPlainString(value) ? value : quote(value)
        case .quoted, .literalBlockWhenMultiline:
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
        let value = String(line)
        guard !containsCommentStart(value), !containsMappingSeparator(value) else {
            return false
        }
        guard let first = line.first else {
            return false
        }
        return canRenderLiteralBlockLineStarting(with: first, line: line)
    }

    func canRenderLiteralBlockLineStarting(
        with first: Character,
        line: Substring,
    ) -> Bool {
        switch first {
        case "#", ",", "[", "]", "{", "}", "&", "*", "!", "|", ">", "'", "\"", "`":
            false
        case "-":
            !hasOnlyIndicator(first, line: line) && line.dropFirst().first != " "
        case "?":
            !hasOnlyIndicator(first, line: line) && line.dropFirst().first != " "
        case ":":
            !hasOnlyIndicator(first, line: line) && line.dropFirst().first != " "
        default:
            true
        }
    }

    func hasOnlyIndicator(
        _ indicator: Character,
        line: Substring,
    ) -> Bool {
        line.count == 1 && line.first == indicator
    }

    func containsCommentStart(_ value: String) -> Bool {
        var previousWasWhitespace = true
        for character in value {
            if character == "#", previousWasWhitespace {
                return true
            }
            previousWasWhitespace = character.isWhitespace
        }
        return false
    }

    func containsMappingSeparator(_ value: String) -> Bool {
        var previousWasColon = false
        for character in value {
            if previousWasColon, isMappingSeparatorBoundary(character) {
                return true
            }
            previousWasColon = character == ":"
        }
        return previousWasColon
    }

    func isMappingSeparatorBoundary(_ character: Character) -> Bool {
        character.isWhitespace
            || character == ","
            || character == "]"
            || character == "}"
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

    func canRenderFlowPlainString(_ value: String) -> Bool {
        canRenderPlainString(value) && !containsFlowDelimiter(value)
    }

    func containsFlowDelimiter(_ value: String) -> Bool {
        value.contains(",")
            || value.contains("[")
            || value.contains("]")
            || value.contains("{")
            || value.contains("}")
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
        canRenderPlainString(key) ? key : quote(key)
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
