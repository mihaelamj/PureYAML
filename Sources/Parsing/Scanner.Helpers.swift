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
        if character == ":", isMappingValueBoundary(state.reader.peek(offset: 1)) {
            return true
        }
        if state.flowDepth > 0, isFlowDelimiter(character) {
            return true
        }
        return false
    }
}
