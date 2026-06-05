extension PureYAML.Parsing.Scanner {
    func scanDirectiveOrDocumentMarker(_ state: inout State) throws -> Bool {
        guard state.indentation.last == 0 else {
            return false
        }
        if state.reader.peek() == "%" {
            try scanDirective(&state)
            return true
        }
        if state.reader.peek() == "#" {
            return false
        }
        if startsWith("---", state.reader), isIndicatorBoundary(state.reader.peek(offset: 3)) {
            guard !state.hasDocumentContent, !state.hasDocumentStartMarker, !state.isDocumentClosed else {
                throw PureYAML.Parsing.ParseError.unsupportedMultiDocumentStream(line: state.reader.mark.line)
            }
            state.hasDocumentStartMarker = true
            skipLine(&state)
            return true
        }
        if startsWith("...", state.reader), isIndicatorBoundary(state.reader.peek(offset: 3)) {
            guard !state.isDocumentClosed else {
                throw PureYAML.Parsing.ParseError.unsupportedMultiDocumentStream(line: state.reader.mark.line)
            }
            state.isDocumentClosed = true
            skipLine(&state)
            return true
        }
        guard !state.isDocumentClosed else {
            throw PureYAML.Parsing.ParseError.unsupportedMultiDocumentStream(line: state.reader.mark.line)
        }
        return false
    }

    func scanDirective(_ state: inout State) throws {
        let start = state.reader.mark
        let line = state.reader.consume { character in
            !isLineBreak(character)
        }
        let parts = line.split(separator: " ").map(String.init)
        guard let name = parts.first else {
            return
        }
        guard !state.hasDocumentContent, !state.hasDocumentStartMarker, !state.isDocumentClosed else {
            throw PureYAML.Parsing.ParseError.unsupportedDirective(name: name, line: start.line)
        }
        switch name {
        case "%YAML":
            guard parts.indices.contains(1), parts[1] == "1.1" || parts[1] == "1.2" else {
                throw PureYAML.Parsing.ParseError.incompatibleYAMLDirective(line: start.line)
            }
        case "%TAG":
            guard parts.count >= 3 else {
                return
            }
            state.tagHandles[parts[1]] = parts[2]
        default:
            throw PureYAML.Parsing.ParseError.unsupportedDirective(name: name, line: start.line)
        }
    }
}
