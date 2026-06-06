extension PureYAML.Parsing {
    private final class TokenScannerStateBox {
        var state: Scanner.State

        init(state: Scanner.State) {
            self.state = state
        }
    }

    struct TokenCursor {
        private var tokens: [Token]
        private(set) var index: Int
        private var previousToken: Token?
        private var scanner: Scanner?
        private var scannerBox: TokenScannerStateBox?

        init(tokens: [Token]) {
            self.tokens = tokens.filter { !$0.kind.isComment }
            index = 0
            previousToken = nil
            scanner = nil
            scannerBox = nil
        }

        init(yaml: String, scanner: Scanner = .init()) {
            var state = Scanner.State(reader: Reader(yaml))
            state.append(.streamStart)
            tokens = state.tokens.filter { !$0.kind.isComment }
            state.tokens.removeAll(keepingCapacity: true)
            index = 0
            previousToken = nil
            self.scanner = scanner
            scannerBox = TokenScannerStateBox(state: state)
        }

        var current: Token? {
            guard tokens.indices.contains(index) else {
                return nil
            }
            return tokens[index]
        }

        var previous: Token? {
            previousToken
        }

        mutating func peek(offset: Int = 1) throws -> Token? {
            try ensureAvailable(offset: offset)
            let targetIndex = index + offset
            guard tokens.indices.contains(targetIndex) else {
                return nil
            }
            return tokens[targetIndex]
        }

        mutating func advance() throws -> Token? {
            try ensureAvailable(offset: 0)
            guard tokens.indices.contains(index) else {
                return nil
            }
            let token = tokens[index]
            previousToken = token
            index += 1
            compactConsumedTokens()
            try ensureAvailable(offset: 0)
            return token
        }

        private mutating func ensureAvailable(offset: Int) throws {
            while tokens.count <= index + offset, scannerBox != nil {
                try scanMoreTokens()
            }
        }

        private mutating func scanMoreTokens() throws {
            guard let scanner, let scannerBox else {
                return
            }

            while scannerBox.state.tokens.isEmpty {
                guard !scannerBox.state.reader.isAtEnd else {
                    scanner.closeIndentation(&scannerBox.state)
                    scannerBox.state.append(.streamEnd)
                    drainScannedTokens(from: &scannerBox.state)
                    self.scannerBox = nil
                    return
                }

                if scanner.isLineBreak(scannerBox.state.reader.peek()) {
                    scannerBox.state.reader.advance()
                    scannerBox.state.isAtLineStart = true
                    continue
                }

                if scannerBox.state.isAtLineStart {
                    try scanner.scanIndentation(&scannerBox.state)
                    if scannerBox.state.reader.isAtEnd {
                        continue
                    }
                    if scanner.isLineBreak(scannerBox.state.reader.peek()) {
                        continue
                    }
                    if try scanner.scanDirectiveOrDocumentMarker(&scannerBox.state) {
                        if !scannerBox.state.tokens.isEmpty {
                            break
                        }
                        continue
                    }
                    scannerBox.state.isAtLineStart = false
                }

                try scanner.scanToken(&scannerBox.state)
            }

            drainScannedTokens(from: &scannerBox.state)
        }

        private mutating func drainScannedTokens(from state: inout Scanner.State) {
            tokens.append(contentsOf: state.tokens.filter { !$0.kind.isComment })
            state.tokens.removeAll(keepingCapacity: true)
        }

        private mutating func compactConsumedTokens() {
            guard index > 4096 else {
                return
            }
            tokens.removeFirst(index)
            index = 0
        }
    }
}

extension PureYAML.Parsing.TokenKind {
    var isBlockEntry: Bool {
        if case .blockEntry = self {
            return true
        }
        return false
    }

    var isComment: Bool {
        if case .comment = self {
            return true
        }
        return false
    }

    var isDedent: Bool {
        if case .dedent = self {
            return true
        }
        return false
    }

    var isDocumentEnd: Bool {
        if case .documentEnd = self {
            return true
        }
        return false
    }

    var isDocumentStart: Bool {
        if case .documentStart = self {
            return true
        }
        return false
    }

    var isFlowTerminator: Bool {
        switch self {
        case .flowEntry, .flowMappingEnd, .flowSequenceEnd:
            true
        default:
            false
        }
    }

    var isIndent: Bool {
        if case .indent = self {
            return true
        }
        return false
    }

    var isMappingKey: Bool {
        if case .mappingKey = self {
            return true
        }
        return false
    }

    var isStreamEnd: Bool {
        if case .streamEnd = self {
            return true
        }
        return false
    }

    var isTerminator: Bool {
        isDedent || isDocumentEnd || isDocumentStart || isFlowTerminator || isStreamEnd
    }
}
