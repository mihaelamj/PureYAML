extension PureYAML.Parsing.Scanner {
    func startsWith(
        _ prefix: String,
        _ reader: PureYAML.Parsing.Reader,
    ) -> Bool {
        for (offset, character) in prefix.enumerated() {
            guard reader.peek(offset: offset) == character else {
                return false
            }
        }
        return true
    }

    func isLineBreak(_ character: Character?) -> Bool {
        character == "\n" || character == "\r" || character == "\r\n"
    }

    func isBlockEntry(_ reader: PureYAML.Parsing.Reader) -> Bool {
        reader.peek() == "-" && isIndicatorBoundary(reader.peek(offset: 1))
    }

    func isIndicatorBoundary(_ character: Character?) -> Bool {
        guard let character else {
            return true
        }
        return character == " " || isLineBreak(character)
    }

    func isMappingValueBoundary(_ character: Character?) -> Bool {
        guard let character else {
            return true
        }
        return character == " "
            || isLineBreak(character)
            || character == ","
            || character == "]"
            || character == "}"
    }

    func isBlockMappingValueBoundary(_ character: Character?) -> Bool {
        guard let character else {
            return true
        }
        return character == " " || isLineBreak(character)
    }

    func isTokenTerminator(_ character: Character) -> Bool {
        character == " "
            || isLineBreak(character)
            || character == ","
            || character == "["
            || character == "]"
            || character == "{"
            || character == "}"
            || character == "#"
    }

    func canStartAnchorName(_ character: Character?) -> Bool {
        guard let character else {
            return false
        }
        return !isTokenTerminator(character)
            && character != "*"
            && character != "&"
            && character != "!"
            && character != "\""
            && character != "'"
    }

    func hasNodeOnSameLine(afterCurrentPositionIn reader: PureYAML.Parsing.Reader) -> Bool {
        var offset = 0
        while reader.peek(offset: offset) == " " {
            offset += 1
        }
        guard let character = reader.peek(offset: offset) else {
            return false
        }
        return !isLineBreak(character) && character != "#"
    }

    func isFlowDelimiter(_ character: Character) -> Bool {
        character == ","
            || character == "["
            || character == "]"
            || character == "{"
            || character == "}"
    }

    func isBlockScalarHeaderCharacter(_ character: Character) -> Bool {
        character == "+"
            || character == "-"
            || character.isNumber
    }

    func trimTrailingSpaces(_ value: String) -> String {
        var end = value.endIndex
        while end > value.startIndex {
            let previous = value.index(before: end)
            guard value[previous] == " " else {
                break
            }
            end = previous
        }
        return String(value[..<end])
    }

    func scanPlainScalarContinuations(
        after firstLine: String,
        state: inout State,
    ) -> String {
        var value = firstLine
        while true {
            var probe = state.reader
            guard isLineBreak(probe.peek()) else {
                return value
            }

            probe.advance()
            var blankLineCount = 0
            while true {
                var blankProbe = probe
                _ = blankProbe.consume { character in
                    character == " "
                }
                guard isLineBreak(blankProbe.peek()) else {
                    break
                }
                blankProbe.advance()
                probe = blankProbe
                blankLineCount += 1
            }

            _ = probe.consume { character in
                character == " "
            }
            let indentationWidth = probe.mark.column - 1

            guard !probe.isAtEnd, !isLineBreak(probe.peek()), probe.peek() != "#" else {
                return value
            }

            let baseIndentation = plainScalarContinuationBaseIndentation(state: state)
            guard indentationWidth > baseIndentation else {
                return value
            }
            if isBlockEntry(probe), state.validImplicitIndentation.contains(indentationWidth) {
                return value
            }

            var continuationState = state
            continuationState.reader = probe
            let continuation = scanPlainScalarContinuationLine(&continuationState)
            guard !isAtMappingValueIndicator(state: continuationState) else {
                return value
            }

            state = continuationState
            if blankLineCount == 0 {
                value += " "
            } else {
                value += String(repeating: "\n", count: blankLineCount)
            }
            value += continuation
        }
    }

    func plainScalarContinuationBaseIndentation(state: State) -> Int {
        state.indentation.last ?? 0
    }

    func scanPlainScalarContinuationLine(_ state: inout State) -> String {
        var value = ""
        while let character = state.reader.peek(), !isLineBreak(character) {
            if character == " ", state.reader.peek(offset: 1) == "#" {
                break
            }
            if character == "#", value.isEmpty || value.last == " " {
                break
            }
            if character == ":", shouldEndPlainScalarAtMappingValue(state: state) {
                break
            }
            if state.flowDepth > 0, isFlowDelimiter(character) {
                break
            }
            value.append(character)
            state.reader.advance()
        }
        return trimTrailingSpaces(value)
    }

    func skipLine(_ state: inout State) {
        _ = state.reader.consume { character in
            !isLineBreak(character)
        }
    }

    func expandTag(
        _ tag: String,
        state: State,
    ) -> String {
        let handles = state.tagHandles.keys.sorted { first, second in
            first.count > second.count
        }
        for handle in handles where tag.hasPrefix(handle) {
            let suffix = tag.dropFirst(handle.count)
            return (state.tagHandles[handle] ?? handle) + suffix
        }
        return tag
    }

    func shouldEndPlainScalar(
        _ character: Character,
        state: State,
        accumulated: String,
    ) -> Bool {
        if isLineBreak(character) {
            return true
        }
        if character == " ", state.reader.peek(offset: 1) == "#" {
            return true
        }
        if character == "#", accumulated.isEmpty || accumulated.last == " " {
            return true
        }
        if character == ":", shouldEndPlainScalarAtMappingValue(state: state) {
            return true
        }
        if state.flowDepth > 0, isFlowDelimiter(character) {
            return true
        }
        return false
    }

    func shouldEndPlainScalarAtMappingValue(state: State) -> Bool {
        if state.flowDepth > 0 {
            return isMappingValueBoundary(state.reader.peek(offset: 1))
        }
        return isBlockMappingValueBoundary(state.reader.peek(offset: 1))
    }

    func isAtMappingValueIndicator(state: State) -> Bool {
        state.reader.peek() == ":" && shouldEndPlainScalarAtMappingValue(state: state)
    }
}
