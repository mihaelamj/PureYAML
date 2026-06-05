extension PureYAML.Parsing {
    struct TokenCursor {
        private var tokens: [Token]
        private(set) var index: Int

        init(tokens: [Token]) {
            self.tokens = tokens.filter { !$0.kind.isComment }
            index = 0
        }

        var current: Token? {
            guard tokens.indices.contains(index) else {
                return nil
            }
            return tokens[index]
        }

        var previous: Token? {
            let previousIndex = index - 1
            guard tokens.indices.contains(previousIndex) else {
                return nil
            }
            return tokens[previousIndex]
        }

        mutating func advance() -> Token? {
            guard let token = current else {
                return nil
            }
            index += 1
            return token
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
