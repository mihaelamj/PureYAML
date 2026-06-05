extension PureYAML.Parsing.TokenEventParser {
    mutating func parseBlockSequence(
        properties: PureYAML.Parsing.NodeProperties,
    ) throws -> PureYAML.Parsing.NodeResult {
        let start = try expect("block sequence entry") { $0.isBlockEntry }
        let startMark = properties.mark ?? start.mark
        var endMark = start.endMark
        events.append(.sequenceStart(
            anchor: properties.anchor,
            tag: properties.tag,
            style: .block,
            mark: startMark,
        ))

        try parseBlockSequenceItem(after: start, endMark: &endMark)
        while cursor.current?.kind.isBlockEntry == true {
            let entry = try expect("block sequence entry") { $0.isBlockEntry }
            try parseBlockSequenceItem(after: entry, endMark: &endMark)
        }
        if let current = cursor.current, current.kind.isMappingKey {
            throw PureYAML.Parsing.ParseError.mixedCollectionStyles(line: current.mark.line)
        }

        events.append(.sequenceEnd(mark: endMark))
        return PureYAML.Parsing.NodeResult(kind: .sequence, endMark: endMark)
    }

    mutating func parseBlockSequenceItem(
        after entry: PureYAML.Parsing.Token,
        endMark: inout PureYAML.Parsing.Mark,
    ) throws {
        if hasNodeOnSameLine(after: entry) {
            let properties = consumeProperties()
            if cursor.current?.kind.isIndent == true {
                _ = try expect("indent") { $0.isIndent }
                endMark = try parseNode(properties: properties).endMark
                _ = try expect("dedent") { $0.isDedent }
                return
            }
            if cursor.current?.kind.isMappingKey == true {
                endMark = try parseBlockMapping(
                    properties: properties,
                    includeIndentedContinuation: true,
                ).endMark
            } else {
                endMark = try parseNode(properties: properties).endMark
            }
        } else if cursor.current?.kind.isIndent == true {
            _ = try expect("indent") { $0.isIndent }
            endMark = try parseNode().endMark
            _ = try expect("dedent") { $0.isDedent }
        } else {
            let mark = entry.endMark
            events.append(.scalar(value: "", anchor: nil, tag: nil, style: .plain, mark: mark))
            endMark = mark
        }
    }

    mutating func parseBlockMapping(
        properties: PureYAML.Parsing.NodeProperties,
        includeIndentedContinuation: Bool,
    ) throws -> PureYAML.Parsing.NodeResult {
        let startMark = properties.mark ?? cursor.current?.mark ?? .start
        var endMark = startMark
        events.append(.mappingStart(
            anchor: properties.anchor,
            tag: properties.tag,
            style: .block,
            mark: startMark,
        ))
        while cursor.current?.kind.isMappingKey == true {
            endMark = try parseMappingPair().endMark
        }
        while includeIndentedContinuation, cursor.current?.kind.isIndent == true {
            _ = try expect("indent") { $0.isIndent }
            guard cursor.current?.kind.isMappingKey == true else {
                throw unexpectedToken(expected: "mapping key")
            }
            while cursor.current?.kind.isMappingKey == true {
                endMark = try parseMappingPair().endMark
            }
            _ = try expect("dedent") { $0.isDedent }
        }
        if let current = cursor.current, !canEndBlockMapping(at: current) {
            throw PureYAML.Parsing.ParseError.unexpectedToken(
                expected: "mapping key",
                actual: current.kind.description,
                line: current.mark.line,
                column: current.mark.column,
            )
        }
        events.append(.mappingEnd(mark: endMark))
        return PureYAML.Parsing.NodeResult(kind: .mapping, endMark: endMark)
    }

    mutating func parseBlockScalar(
        properties: PureYAML.Parsing.NodeProperties,
    ) throws -> PureYAML.Parsing.NodeResult {
        let header = try expect("block scalar header") { kind in
            if case .blockScalarHeader = kind {
                return true
            }
            return false
        }
        var lines: [String] = []
        var endMark = header.endMark
        if cursor.current?.kind.isIndent == true {
            _ = try expect("indent") { $0.isIndent }
            while cursor.current != nil, cursor.current?.kind.isDedent != true {
                guard case let .scalar(value, style) = cursor.current?.kind else {
                    throw unexpectedToken(expected: "block scalar content")
                }
                let token = cursor.advance() ?? header
                try lines.append(decodeScalar(value, style: style, line: token.mark.line))
                endMark = token.endMark
            }
            _ = try expect("dedent") { $0.isDedent }
        }

        let value = blockScalarValue(lines: lines, header: header.kind)
        let mark = properties.mark ?? header.mark
        events.append(.scalar(
            value: value,
            anchor: properties.anchor,
            tag: properties.tag,
            style: scalarStyle(for: header.kind),
            mark: mark,
        ))
        return PureYAML.Parsing.NodeResult(kind: .scalar, endMark: endMark)
    }

    func scalarStyle(for kind: PureYAML.Parsing.TokenKind) -> PureYAML.Parsing.ScalarStyle {
        switch kind {
        case .blockScalarHeader(.folded, _):
            .folded
        case .blockScalarHeader(.literal, _):
            .literal
        default:
            .plain
        }
    }

    func blockScalarValue(
        lines: [String],
        header: PureYAML.Parsing.TokenKind,
    ) -> String {
        let (style, chomping): (PureYAML.Parsing.BlockScalarStyle, PureYAML.Parsing.BlockScalarChomping)
        switch header {
        case let .blockScalarHeader(headerStyle, headerChomping):
            style = headerStyle
            chomping = headerChomping
        default:
            style = .literal
            chomping = .clip
        }

        let separator = style == .folded ? " " : "\n"
        let content = lines.joined(separator: separator)
        guard !content.isEmpty else {
            return ""
        }

        switch chomping {
        case .strip:
            return content
        case .clip:
            return content + "\n"
        }
    }
}
