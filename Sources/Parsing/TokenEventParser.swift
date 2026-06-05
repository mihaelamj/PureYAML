extension PureYAML.Parsing {
    struct TokenEventParser {
        var cursor: TokenCursor
        let scalarParser: Parser
        var events: [Event]

        init(
            tokens: [Token],
            scalarParser: Parser,
        ) {
            cursor = TokenCursor(tokens: tokens)
            self.scalarParser = scalarParser
            events = []
        }

        mutating func parse() throws -> [Event] {
            let streamStart = try expect("stream start") { kind in
                if case .streamStart = kind {
                    return true
                }
                return false
            }
            guard cursor.current?.kind.isStreamEnd != true else {
                throw ParseError.emptyDocument
            }

            events.append(.streamStart(mark: streamStart.mark))
            events.append(.documentStart(mark: streamStart.mark))
            let result = try parseNode()
            guard cursor.current?.kind.isStreamEnd == true else {
                throw unexpectedToken(expected: "stream end")
            }
            _ = try expect("stream end") { kind in
                if case .streamEnd = kind {
                    return true
                }
                return false
            }
            events.append(.documentEnd(mark: result.endMark))
            events.append(.streamEnd(mark: result.endMark))
            return events
        }
    }
}

extension PureYAML.Parsing.TokenEventParser {
    mutating func parseNode() throws -> PureYAML.Parsing.NodeResult {
        let properties = consumeProperties()
        guard let token = cursor.current, !token.kind.isTerminator else {
            let mark = properties.mark ?? cursor.current?.mark ?? cursor.previous?.endMark ?? .start
            throw PureYAML.Parsing.ParseError.expectedNode(line: mark.line, column: mark.column)
        }

        switch token.kind {
        case let .alias(anchor):
            _ = cursor.advance()
            let mark = properties.mark ?? token.mark
            events.append(.alias(anchor: anchor, mark: mark))
            return PureYAML.Parsing.NodeResult(kind: .alias, endMark: token.endMark)
        case .blockEntry:
            return try parseBlockSequence(properties: properties)
        case .blockScalarHeader:
            return try parseBlockScalar(properties: properties)
        case .flowMappingStart:
            return try parseFlowMapping(properties: properties)
        case .flowSequenceStart:
            return try parseFlowSequence(properties: properties)
        case .mappingKey:
            return try parseBlockMapping(
                properties: properties,
                includeIndentedContinuation: false,
            )
        case let .scalar(value, style):
            _ = cursor.advance()
            let decoded = try decodeScalar(value, style: style, line: token.mark.line)
            let mark = properties.mark ?? token.mark
            events.append(.scalar(
                value: decoded,
                anchor: properties.anchor,
                tag: properties.tag,
                style: style,
                mark: mark,
            ))
            return PureYAML.Parsing.NodeResult(kind: .scalar, endMark: token.endMark)
        default:
            throw PureYAML.Parsing.ParseError.expectedNode(line: token.mark.line, column: token.mark.column)
        }
    }
}
