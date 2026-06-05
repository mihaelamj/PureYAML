public extension PureYAML.Parsing {
    /// Pure-Swift YAML parser for block mappings, sequences, and common scalars.
    struct Parser: Sendable {
        public init() {}

        public func parse(_ yaml: String) throws -> PureYAML.Model.Value {
            let lines = try preprocess(yaml)
            guard !lines.isEmpty else {
                throw ParseError.emptyDocument
            }
            var index = 0
            let value = try parseBlock(lines, index: &index, indent: lines[0].indent)
            if index < lines.count {
                throw ParseError.unexpectedIndentation(line: lines[index].number)
            }
            return value
        }
    }
}

extension PureYAML.Parsing.Parser {
    func parseBlock(
        _ lines: [PureYAML.Parsing.Line],
        index: inout Int,
        indent: Int,
    ) throws -> PureYAML.Model.Value {
        guard index < lines.count else {
            return .null
        }
        let line = lines[index]
        if line.indent < indent {
            return .null
        }
        guard line.indent == indent else {
            throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: line.number)
        }
        if line.content.hasPrefix("-") {
            return try parseSequence(lines, index: &index, indent: indent)
        }
        if splitMappingEntry(line.content) != nil {
            return try parseMapping(lines, index: &index, indent: indent)
        }
        index += 1
        return try parseScalar(line.content, line: line.number)
    }

    func parseSequence(
        _ lines: [PureYAML.Parsing.Line],
        index: inout Int,
        indent: Int,
    ) throws -> PureYAML.Model.Value {
        var values: [PureYAML.Model.Value] = []
        while index < lines.count {
            let line = lines[index]
            if line.indent < indent {
                break
            }
            guard line.indent == indent else {
                throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: line.number)
            }
            guard line.content == "-" || line.content.hasPrefix("- ") else {
                throw PureYAML.Parsing.ParseError.mixedCollectionStyles(line: line.number)
            }

            let rest = trim(String(line.content.dropFirst()))
            index += 1
            if rest.isEmpty {
                if index < lines.count, lines[index].indent > indent {
                    try values.append(parseBlock(lines, index: &index, indent: lines[index].indent))
                } else {
                    values.append(.null)
                }
            } else if let (key, valueText) = splitMappingEntry(rest) {
                var pairs = try [
                    PureYAML.Model.Pair(
                        key: key,
                        value: parseInlineOrNestedValue(valueText, lines: lines, index: &index, parentIndent: indent, line: line.number),
                    ),
                ]
                if index < lines.count, lines[index].indent > indent {
                    try pairs.append(contentsOf: parseMappingPairs(lines, index: &index, indent: lines[index].indent))
                }
                values.append(.mapping(PureYAML.Model.Mapping(pairs)))
            } else {
                try values.append(parseScalar(rest, line: line.number))
            }
        }
        return .sequence(values)
    }

    func parseMapping(
        _ lines: [PureYAML.Parsing.Line],
        index: inout Int,
        indent: Int,
    ) throws -> PureYAML.Model.Value {
        try .mapping(PureYAML.Model.Mapping(parseMappingPairs(lines, index: &index, indent: indent)))
    }

    func parseMappingPairs(
        _ lines: [PureYAML.Parsing.Line],
        index: inout Int,
        indent: Int,
    ) throws -> [PureYAML.Model.Pair] {
        var pairs: [PureYAML.Model.Pair] = []
        while index < lines.count {
            let line = lines[index]
            if line.indent < indent {
                break
            }
            guard line.indent == indent else {
                throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: line.number)
            }
            guard let (key, valueText) = splitMappingEntry(line.content) else {
                throw PureYAML.Parsing.ParseError.expectedMappingKey(line: line.number)
            }
            index += 1
            let value = try parseInlineOrNestedValue(valueText, lines: lines, index: &index, parentIndent: indent, line: line.number)
            pairs.append(PureYAML.Model.Pair(key: key, value: value))
        }
        return pairs
    }

    func parseInlineOrNestedValue(
        _ valueText: String,
        lines: [PureYAML.Parsing.Line],
        index: inout Int,
        parentIndent: Int,
        line: Int,
    ) throws -> PureYAML.Model.Value {
        if !valueText.isEmpty {
            return try parseScalar(valueText, line: line)
        }
        if index < lines.count, lines[index].indent > parentIndent {
            return try parseBlock(lines, index: &index, indent: lines[index].indent)
        }
        return .null
    }
}
