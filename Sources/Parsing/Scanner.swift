extension PureYAML.Parsing {
    struct Scanner {
        init() {}

        func scan(_ yaml: String) throws -> [Token] {
            var state = State(reader: Reader(yaml))
            state.append(.streamStart)

            while !state.reader.isAtEnd {
                if isLineBreak(state.reader.peek()) {
                    state.reader.advance()
                    state.isAtLineStart = true
                    continue
                }

                if state.isAtLineStart {
                    try scanIndentation(&state)
                    if state.reader.isAtEnd {
                        break
                    }
                    if isLineBreak(state.reader.peek()) {
                        continue
                    }
                    if try scanDirectiveOrDocumentMarker(&state) {
                        continue
                    }
                    state.isAtLineStart = false
                }

                try scanToken(&state)
            }

            closeIndentation(&state)
            state.append(.streamEnd)
            return state.tokens
        }
    }
}

extension PureYAML.Parsing.Scanner {
    struct State {
        var reader: PureYAML.Parsing.Reader
        var tokens: [PureYAML.Parsing.Token] = []
        var indentation: [Int] = [0]
        var isAtLineStart = true
        var hasDocumentContent = false
        var hasDocumentStartMarker = false
        var isDocumentClosed = false
        var flowDepth = 0
        var flowContexts: [PureYAML.Parsing.ScannerFlowContext] = []
        var validImplicitIndentation: Set<Int> = []
        var pendingBlockScalarIndentation = false
        var pendingBlockScalarIndentationIndicator: Int?
        var blockScalarIndentation: Int?
        var blockScalarContentPrefix = ""
        var tagHandles = [
            "!": "!",
            "!!": "tag:yaml.org,2002:",
        ]

        mutating func append(_ kind: PureYAML.Parsing.TokenKind) {
            let mark = reader.mark
            tokens.append(PureYAML.Parsing.Token(kind: kind, mark: mark, endMark: mark))
            markDocumentContentIfNeeded(kind)
        }

        mutating func append(
            _ kind: PureYAML.Parsing.TokenKind,
            mark: PureYAML.Parsing.Mark,
            endMark: PureYAML.Parsing.Mark,
        ) {
            tokens.append(PureYAML.Parsing.Token(kind: kind, mark: mark, endMark: endMark))
            markDocumentContentIfNeeded(kind)
        }

        mutating func markDocumentContentIfNeeded(_ kind: PureYAML.Parsing.TokenKind) {
            switch kind {
            case .comment, .dedent, .documentEnd, .documentStart, .indent, .streamEnd, .streamStart:
                return
            default:
                hasDocumentContent = true
            }
        }

        var isExpectingFlowMappingKey: Bool {
            flowContexts.last?.kind == .mapping
                && flowContexts.last?.isExpectingKey == true
        }
    }
}

extension PureYAML.Parsing.Scanner {
    func scanToken(_ state: inout State) throws {
        skipSeparation(&state)
        guard let character = state.reader.peek(), !isLineBreak(character) else {
            return
        }

        if state.blockScalarIndentation != nil {
            scanBlockScalarContent(&state)
            return
        }
        if try scanLineIndicatorToken(character, state: &state) {
            return
        }
        if scanFlowToken(character, state: &state) {
            return
        }
        if try scanQuotedOrBlockScalarToken(character, state: &state) {
            return
        }
        if try scanNodePropertyToken(character, state: &state) {
            return
        }
        scanPlainScalar(&state)
    }

    func scanLineIndicatorToken(
        _ character: Character,
        state: inout State,
    ) throws -> Bool {
        switch character {
        case "#":
            scanComment(&state)
            return true
        case "-" where isBlockEntry(state.reader):
            scanFixedToken(.blockEntry, state: &state)
            return true
        case "?" where isIndicatorBoundary(state.reader.peek(offset: 1)):
            scanFixedToken(.mappingKey, state: &state)
            return true
        case ":" where isAtMappingValueIndicator(state: state):
            scanFixedToken(.mappingValue, state: &state)
            return true
        default:
            return false
        }
    }

    func scanFlowToken(
        _ character: Character,
        state: inout State,
    ) -> Bool {
        switch character {
        case "[":
            state.flowDepth += 1
            state.flowContexts.append(.init(kind: .sequence, isExpectingKey: false))
            scanFixedToken(.flowSequenceStart, state: &state)
            return true
        case "]":
            state.flowDepth = max(0, state.flowDepth - 1)
            scanFixedToken(.flowSequenceEnd, state: &state)
            _ = state.flowContexts.popLast()
            return true
        case "{":
            state.flowDepth += 1
            state.flowContexts.append(.init(kind: .mapping, isExpectingKey: true))
            scanFixedToken(.flowMappingStart, state: &state)
            return true
        case "}":
            state.flowDepth = max(0, state.flowDepth - 1)
            scanFixedToken(.flowMappingEnd, state: &state)
            _ = state.flowContexts.popLast()
            return true
        case ",":
            scanFixedToken(.flowEntry, state: &state)
            if state.flowContexts.last?.kind == .mapping {
                state.flowContexts[state.flowContexts.count - 1].isExpectingKey = true
            }
            return true
        default:
            return false
        }
    }

    func scanNodePropertyToken(
        _ character: Character,
        state: inout State,
    ) throws -> Bool {
        switch character {
        case "&":
            try scanNamedToken(
                kind: PureYAML.Parsing.TokenKind.anchor,
                missingNameError: PureYAML.Parsing.ParseError.expectedAnchorName,
                state: &state,
            )
            return true
        case "*":
            try scanNamedToken(
                kind: PureYAML.Parsing.TokenKind.alias,
                missingNameError: PureYAML.Parsing.ParseError.expectedAliasName,
                state: &state,
            )
            return true
        case "!":
            try scanTag(&state)
            return true
        default:
            return false
        }
    }

    func scanQuotedOrBlockScalarToken(
        _ character: Character,
        state: inout State,
    ) throws -> Bool {
        switch character {
        case "\"":
            try scanQuotedScalar(.doubleQuoted, state: &state)
            return true
        case "'":
            try scanQuotedScalar(.singleQuoted, state: &state)
            return true
        case "|":
            scanBlockScalarHeader(.literal, state: &state)
            return true
        case ">":
            scanBlockScalarHeader(.folded, state: &state)
            return true
        default:
            return false
        }
    }

    func skipSeparation(_ state: inout State) {
        while state.reader.peek() == " " {
            state.reader.advance()
        }
    }

    func scanFixedToken(
        _ kind: PureYAML.Parsing.TokenKind,
        state: inout State,
    ) {
        let start = state.reader.mark
        state.reader.advance()
        state.append(kind, mark: start, endMark: state.reader.mark)
        if case .blockEntry = kind, hasNodeOnSameLine(afterCurrentPositionIn: state.reader) {
            state.validImplicitIndentation.insert(start.column + 1)
        }
        if case .mappingValue = kind, state.flowContexts.last?.kind == .mapping {
            state.flowContexts[state.flowContexts.count - 1].isExpectingKey = false
        }
    }

    func scanComment(_ state: inout State) {
        let start = state.reader.mark
        state.reader.advance()
        if state.reader.peek() == " " {
            state.reader.advance()
        }
        let value = state.reader.consume { character in
            !isLineBreak(character)
        }
        state.append(.comment(value), mark: start, endMark: state.reader.mark)
    }

    func scanQuotedScalar(
        _ style: PureYAML.Parsing.ScalarStyle,
        state: inout State,
    ) throws {
        let start = state.reader.mark
        let quote: Character = style == .doubleQuoted ? "\"" : "'"
        state.reader.advance()
        var value = ""
        var previousWasEscape = false
        while let character = state.reader.peek() {
            if style == .singleQuoted, character == quote, state.reader.peek(offset: 1) == quote {
                value.append(character)
                state.reader.advance()
                value.append(character)
                state.reader.advance()
                continue
            }
            if character == quote, !previousWasEscape {
                break
            }
            value.append(character)
            previousWasEscape = character == "\\" && style == .doubleQuoted && !previousWasEscape
            state.reader.advance()
            if character != "\\" {
                previousWasEscape = false
            }
        }
        guard state.reader.peek() == quote else {
            throw PureYAML.Parsing.ParseError.unterminatedQuotedString(line: start.line)
        }
        state.reader.advance()
        appendMappingKeyIfNeeded(start: start, state: &state)
        state.append(.scalar(value: value, style: style), mark: start, endMark: state.reader.mark)
    }

    func scanBlockScalarHeader(
        _ style: PureYAML.Parsing.BlockScalarStyle,
        state: inout State,
    ) {
        let start = state.reader.mark
        var chomping = PureYAML.Parsing.BlockScalarChomping.clip
        var indentationIndicator: Int?
        state.reader.advance()
        while let character = state.reader.peek(), isBlockScalarHeaderCharacter(character) {
            if character == "-" {
                chomping = .strip
            } else if character.isNumber {
                indentationIndicator = Int(String(character))
            }
            state.reader.advance()
        }
        state.append(
            .blockScalarHeader(style: style, chomping: chomping),
            mark: start,
            endMark: state.reader.mark,
        )
        state.pendingBlockScalarIndentation = true
        state.pendingBlockScalarIndentationIndicator = indentationIndicator
    }

    func scanBlockScalarContent(_ state: inout State) {
        let start = state.reader.mark
        let value = state.blockScalarContentPrefix + state.reader.consume { character in
            !isLineBreak(character)
        }
        state.blockScalarContentPrefix = ""
        state.append(.scalar(value: value, style: .plain), mark: start, endMark: state.reader.mark)
    }

    func scanNamedToken(
        kind: (String) -> PureYAML.Parsing.TokenKind,
        missingNameError: (Int) -> PureYAML.Parsing.ParseError,
        state: inout State,
    ) throws {
        let start = state.reader.mark
        state.reader.advance()
        let name = state.reader.consume { character in
            !isTokenTerminator(character)
        }
        guard !name.isEmpty else {
            throw missingNameError(start.line)
        }
        state.append(kind(name), mark: start, endMark: state.reader.mark)
    }

    func scanTag(_ state: inout State) throws {
        let start = state.reader.mark
        state.reader.advance()
        var value = "!"
        if state.reader.peek() == "<" {
            value.append(state.reader.advance() ?? "<")
            var didClose = false
            while let character = state.reader.peek() {
                value.append(character)
                state.reader.advance()
                if character == ">" {
                    didClose = true
                    break
                }
            }
            guard didClose else {
                throw PureYAML.Parsing.ParseError.unterminatedTag(line: start.line)
            }
        } else {
            value += state.reader.consume { character in
                !isTokenTerminator(character)
            }
            value = expandTag(value, state: state)
        }
        state.append(.tag(value), mark: start, endMark: state.reader.mark)
    }

    func scanPlainScalar(_ state: inout State) {
        let start = state.reader.mark
        var value = ""
        while let character = state.reader.peek() {
            if shouldEndPlainScalar(character, state: state, accumulated: value) {
                break
            }
            value.append(character)
            state.reader.advance()
        }
        var trimmed = trimTrailingSpaces(value)
        let isMappingKey = appendMappingKeyIfNeeded(start: start, state: &state)
        if !isMappingKey {
            trimmed = scanPlainScalarContinuations(
                after: trimmed,
                state: &state,
            )
        }
        state.append(.scalar(value: trimmed, style: .plain), mark: start, endMark: state.reader.mark)
    }
}
