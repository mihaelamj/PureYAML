extension PureYAML.Parsing.TokenEventParser {
    mutating func parseMappingPair() throws -> PureYAML.Parsing.NodeResult {
        _ = try expect("mapping key") { $0.isMappingKey }
        _ = try parseNode()
        let valueIndicator = try expect("mapping value") { kind in
            if case .mappingValue = kind {
                return true
            }
            return false
        }

        if cursor.current?.kind.isIndent == true {
            _ = try expect("indent") { $0.isIndent }
            let result = try parseNode()
            _ = try expect("dedent") { $0.isDedent }
            return result
        }
        if hasNodeOnSameLine(after: valueIndicator) {
            return try parseNode()
        }

        let mark = valueIndicator.endMark
        events.append(.scalar(value: "", anchor: nil, tag: nil, style: .plain, mark: mark))
        return PureYAML.Parsing.NodeResult(kind: .scalar, endMark: mark)
    }

    mutating func consumeProperties() -> PureYAML.Parsing.NodeProperties {
        var properties = PureYAML.Parsing.NodeProperties.none
        while let token = cursor.current {
            switch token.kind {
            case let .anchor(anchor):
                properties.anchor = anchor
                properties.mark = properties.mark ?? token.mark
                _ = cursor.advance()
            case let .tag(tag):
                properties.tag = tag
                properties.mark = properties.mark ?? token.mark
                _ = cursor.advance()
            default:
                return properties
            }
        }
        return properties
    }

    func decodeScalar(
        _ value: String,
        style: PureYAML.Parsing.ScalarStyle,
        line: Int,
    ) throws -> String {
        switch style {
        case .doubleQuoted:
            try scalarParser.parseDoubleQuoted("\"\(value)\"", line: line)
        case .folded, .literal:
            value
        case .plain:
            value
        case .singleQuoted:
            try scalarParser.parseSingleQuoted("'\(value)'", line: line)
        }
    }

    func hasNodeOnSameLine(after token: PureYAML.Parsing.Token) -> Bool {
        guard let current = cursor.current, !current.kind.isTerminator else {
            return false
        }
        return current.mark.line == token.mark.line
    }

    func canEndBlockMapping(at token: PureYAML.Parsing.Token) -> Bool {
        token.kind.isBlockEntry
            || token.kind.isDedent
            || token.kind.isDocumentEnd
            || token.kind.isDocumentStart
            || token.kind.isFlowTerminator
            || token.kind.isStreamEnd
    }

    mutating func expect(
        _ expected: String,
        matching: (PureYAML.Parsing.TokenKind) -> Bool,
    ) throws -> PureYAML.Parsing.Token {
        guard let token = cursor.current else {
            let mark = cursor.previous?.endMark ?? .start
            throw PureYAML.Parsing.ParseError.unexpectedToken(
                expected: expected,
                actual: "end of tokens",
                line: mark.line,
                column: mark.column,
            )
        }
        guard matching(token.kind) else {
            throw PureYAML.Parsing.ParseError.unexpectedToken(
                expected: expected,
                actual: token.kind.description,
                line: token.mark.line,
                column: token.mark.column,
            )
        }
        _ = cursor.advance()
        return token
    }

    func unexpectedToken(expected: String) -> PureYAML.Parsing.ParseError {
        guard let token = cursor.current else {
            let mark = cursor.previous?.endMark ?? .start
            return PureYAML.Parsing.ParseError.unexpectedToken(
                expected: expected,
                actual: "end of tokens",
                line: mark.line,
                column: mark.column,
            )
        }
        return PureYAML.Parsing.ParseError.unexpectedToken(
            expected: expected,
            actual: token.kind.description,
            line: token.mark.line,
            column: token.mark.column,
        )
    }
}
