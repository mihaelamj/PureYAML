extension PureYAML.Parsing.Scanner {
    func scanIndentation(_ state: inout State) throws {
        let start = state.reader.mark
        let width = try scanIndentationWidth(&state)
        guard shouldProcessIndentation(state) else {
            return
        }

        let end = state.reader.mark
        let current = state.indentation.last ?? 0
        if consumeBlockScalarContentIndentation(width: width, state: &state) {
            return
        }

        if let indicator = state.pendingBlockScalarIndentationIndicator {
            try applyExplicitBlockScalarIndentation(
                indicator: indicator,
                width: width,
                current: current,
                marks: (start: start, end: end),
                state: &state,
            )
        } else if width > current {
            applyIncreasedIndentation(width: width, start: start, end: end, state: &state)
        } else if width < current {
            try applyDedentation(width: width, start: start, end: end, state: &state)
        }

        pruneImplicitIndentation(&state)
        clearPendingBlockScalarIndentation(&state)
    }

    func scanIndentationWidth(_ state: inout State) throws -> Int {
        var width = 0
        while let character = state.reader.peek() {
            if character == " " {
                width += 1
                state.reader.advance()
            } else if character == "\t" {
                width = nextTabStop(after: width)
                state.reader.advance()
            } else {
                return width
            }
        }
        return width
    }

    func nextTabStop(after width: Int) -> Int {
        ((width / 4) + 1) * 4
    }

    func shouldProcessIndentation(_ state: State) -> Bool {
        guard !state.reader.isAtEnd, !isLineBreak(state.reader.peek()) else {
            return false
        }
        guard state.reader.peek() != "#" else {
            return false
        }
        return state.flowDepth == 0
    }

    func consumeBlockScalarContentIndentation(
        width: Int,
        state: inout State,
    ) -> Bool {
        guard let blockScalarIndentation = state.blockScalarIndentation else {
            return false
        }
        guard width < blockScalarIndentation else {
            state.blockScalarContentPrefix = String(repeating: " ", count: width - blockScalarIndentation)
            return true
        }
        state.blockScalarIndentation = nil
        state.blockScalarContentPrefix = ""
        return false
    }

    func applyExplicitBlockScalarIndentation(
        indicator: Int,
        width: Int,
        current: Int,
        marks: (start: PureYAML.Parsing.Mark, end: PureYAML.Parsing.Mark),
        state: inout State,
    ) throws {
        let blockScalarIndentation = current + indicator
        guard width >= blockScalarIndentation else {
            throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: marks.end.line)
        }
        state.indentation.append(blockScalarIndentation)
        state.append(.indent(width: blockScalarIndentation), mark: marks.start, endMark: marks.end)
        state.blockScalarIndentation = blockScalarIndentation
        state.blockScalarContentPrefix = String(repeating: " ", count: width - blockScalarIndentation)
        clearPendingBlockScalarIndentation(&state)
    }

    func applyIncreasedIndentation(
        width: Int,
        start: PureYAML.Parsing.Mark,
        end: PureYAML.Parsing.Mark,
        state: inout State,
    ) {
        state.indentation.append(width)
        state.append(.indent(width: width), mark: start, endMark: end)
        guard state.pendingBlockScalarIndentation else {
            return
        }
        state.blockScalarIndentation = width
        state.blockScalarContentPrefix = ""
        clearPendingBlockScalarIndentation(&state)
    }

    func applyDedentation(
        width: Int,
        start: PureYAML.Parsing.Mark,
        end: PureYAML.Parsing.Mark,
        state: inout State,
    ) throws {
        while state.indentation.count > 1, width < (state.indentation.last ?? 0) {
            state.indentation.removeLast()
            state.append(.dedent(width: state.indentation.last ?? 0), mark: end, endMark: end)
        }
        if canUseImplicitIndentation(width: width, state: state) {
            state.indentation.append(width)
            state.append(.indent(width: width), mark: start, endMark: end)
        }
        guard width == state.indentation.last else {
            throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: end.line)
        }
    }

    func canUseImplicitIndentation(
        width: Int,
        state: State,
    ) -> Bool {
        width != state.indentation.last
            && width > (state.indentation.last ?? 0)
            && state.validImplicitIndentation.contains(width)
    }

    func pruneImplicitIndentation(_ state: inout State) {
        let current = state.indentation.last ?? 0
        state.validImplicitIndentation = state.validImplicitIndentation.filter { $0 <= current }
    }

    func clearPendingBlockScalarIndentation(_ state: inout State) {
        state.pendingBlockScalarIndentation = false
        state.pendingBlockScalarIndentationIndicator = nil
    }

    func closeIndentation(_ state: inout State) {
        let mark = state.reader.mark
        while state.indentation.count > 1 {
            state.indentation.removeLast()
            state.append(.dedent(width: state.indentation.last ?? 0), mark: mark, endMark: mark)
        }
    }
}
