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

        let properties = try consumeProperties()
        if cursor.current?.kind.isIndent == true {
            _ = try expect("indent") { $0.isIndent }
            let result: PureYAML.Parsing.NodeResult = if cursor.current?.kind.isBlockEntry == true {
                try parseBlockSequence(
                    properties: properties,
                    allowMappingKeyTerminator: true,
                )
            } else {
                try parseNode(properties: properties)
            }
            if cursor.current?.kind.isDedent == true {
                _ = try expect("dedent") { $0.isDedent }
            } else if cursor.current?.kind.isMappingKey != true {
                _ = try expect("dedent") { $0.isDedent }
            }
            return result
        }
        if properties == .none, try canParsePlainScalarWithContinuation(after: valueIndicator) {
            return try parsePlainScalarWithContinuation(properties: properties)
        }
        if cursor.current?.kind.isMappingKey == true, hasNodeOnSameLine(after: valueIndicator) {
            return try parseBlockMapping(
                properties: properties,
                includeIndentedContinuation: true,
                minimumColumn: cursor.current?.mark.column,
            )
        }
        if properties != .none || hasNodeOnSameLine(after: valueIndicator) {
            return try parseNode(properties: properties)
        }
        if cursor.current?.kind.isBlockEntry == true {
            return try parseBlockSequence(
                properties: properties,
                allowMappingKeyTerminator: true,
            )
        }

        let mark = valueIndicator.endMark
        try emit(.scalar(value: "", anchor: nil, tag: nil, style: .plain, mark: mark))
        return PureYAML.Parsing.NodeResult(kind: .scalar, endMark: mark)
    }

    mutating func parsePlainScalarWithContinuation(
        properties: PureYAML.Parsing.NodeProperties,
    ) throws -> PureYAML.Parsing.NodeResult {
        let first = try expect("plain scalar") { kind in
            if case .scalar(_, .plain) = kind {
                return true
            }
            return false
        }
        var value = try decodedScalar(from: first)
        var endMark = first.endMark

        _ = try expect("indent") { $0.isIndent }
        while isScalar(cursor.current) {
            let token = try cursor.advance() ?? first
            let continuation = try plainContinuationText(from: token)
            value += " " + continuation
            endMark = token.endMark
        }
        _ = try expect("dedent") { $0.isDedent }

        let mark = properties.mark ?? first.mark
        try emit(.scalar(
            value: value,
            anchor: properties.anchor,
            tag: properties.tag,
            style: .plain,
            mark: mark,
        ))
        return PureYAML.Parsing.NodeResult(kind: .scalar, endMark: endMark)
    }

    mutating func consumeProperties() throws -> PureYAML.Parsing.NodeProperties {
        var properties = PureYAML.Parsing.NodeProperties.none
        while let token = cursor.current {
            switch token.kind {
            case let .anchor(anchor):
                properties.anchor = anchor
                properties.mark = properties.mark ?? token.mark
                _ = try cursor.advance()
            case let .tag(tag):
                properties.tag = tag
                properties.mark = properties.mark ?? token.mark
                _ = try cursor.advance()
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

    func decodedScalar(from token: PureYAML.Parsing.Token) throws -> String {
        guard case let .scalar(value, style) = token.kind else {
            throw unexpectedToken(expected: "scalar")
        }
        return try decodeScalar(value, style: style, line: token.mark.line)
    }

    func plainContinuationText(from token: PureYAML.Parsing.Token) throws -> String {
        guard case let .scalar(value, style) = token.kind else {
            throw unexpectedToken(expected: "scalar")
        }
        switch style {
        case .doubleQuoted:
            return "\"\(value)\""
        case .singleQuoted:
            return "'\(value)'"
        case .folded, .literal, .plain:
            return try decodeScalar(value, style: style, line: token.mark.line)
        }
    }

    func hasNodeOnSameLine(after token: PureYAML.Parsing.Token) -> Bool {
        guard let current = cursor.current, !current.kind.isTerminator else {
            return false
        }
        return current.mark.line == token.mark.line
    }

    mutating func canParsePlainScalarWithContinuation(after token: PureYAML.Parsing.Token) throws -> Bool {
        guard case .scalar(_, .plain) = cursor.current?.kind else {
            return false
        }
        guard cursor.current?.mark.line == token.mark.line else {
            return false
        }
        guard try cursor.peek()?.kind.isIndent == true else {
            return false
        }
        guard try isScalar(cursor.peek(offset: 2)) else {
            return false
        }
        return true
    }

    mutating func canParsePlainScalarContinuation() throws -> Bool {
        guard case .scalar(_, .plain) = cursor.current?.kind else {
            return false
        }
        guard try cursor.peek()?.kind.isIndent == true else {
            return false
        }
        guard try isScalar(cursor.peek(offset: 2)) else {
            return false
        }
        return true
    }

    func isScalar(_ token: PureYAML.Parsing.Token?) -> Bool {
        guard case .scalar = token?.kind else {
            return false
        }
        return true
    }

    mutating func consumeDedents(atOrAbove minimumColumn: Int) throws {
        while let width = dedentWidth(cursor.current), width >= minimumColumn {
            _ = try expect("dedent") { $0.isDedent }
        }
    }

    mutating func consumeMappingSiblingBoundaryDedents(minimumColumn: Int) throws {
        while try canConsumeMappingSiblingBoundaryDedent(minimumColumn: minimumColumn) {
            _ = try expect("dedent") { $0.isDedent }
        }
    }

    mutating func canConsumeMappingSiblingBoundaryDedent(minimumColumn: Int) throws -> Bool {
        guard let width = dedentWidth(cursor.current),
              let next = try cursor.peek(),
              next.kind.isMappingKey,
              next.mark.column >= minimumColumn
        else {
            return false
        }
        return width == next.mark.column - 1
    }

    mutating func consumeMappingSiblingBoundaryReindent(minimumColumn: Int) throws {
        guard let dedent = dedentWidth(cursor.current),
              dedent < minimumColumn,
              try indentWidth(cursor.peek()) == minimumColumn,
              let mappingKey = try cursor.peek(offset: 2),
              mappingKey.kind.isMappingKey,
              mappingKey.mark.column == minimumColumn + 1
        else {
            return
        }
        _ = try expect("dedent") { $0.isDedent }
        _ = try expect("indent") { $0.isIndent }
    }

    func dedentWidth(_ token: PureYAML.Parsing.Token?) -> Int? {
        guard case let .dedent(width) = token?.kind else {
            return nil
        }
        return width
    }

    func indentWidth(_ token: PureYAML.Parsing.Token?) -> Int? {
        guard case let .indent(width) = token?.kind else {
            return nil
        }
        return width
    }

    func canContinueBlockMapping(minimumColumn: Int?) -> Bool {
        guard let current = cursor.current, current.kind.isMappingKey else {
            return false
        }
        guard let minimumColumn else {
            return true
        }
        return current.mark.column >= minimumColumn
    }

    func canEndBlockMapping(
        at token: PureYAML.Parsing.Token?,
        minimumColumn: Int? = nil,
    ) -> Bool {
        guard let token else {
            return true
        }
        return token.kind.isBlockEntry
            || token.kind.isDedent
            || token.kind.isDocumentEnd
            || token.kind.isDocumentStart
            || token.kind.isFlowTerminator
            || isLowerColumnMappingKey(token, minimumColumn: minimumColumn)
            || token.kind.isStreamEnd
    }

    func isLowerColumnMappingKey(
        _ token: PureYAML.Parsing.Token?,
        minimumColumn: Int?,
    ) -> Bool {
        guard let token, token.kind.isMappingKey, let minimumColumn else {
            return false
        }
        return token.mark.column < minimumColumn
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
        _ = try cursor.advance()
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
