extension PureYAML.Parsing.Parser {
    func parseEvents(_ yaml: String) throws -> [PureYAML.Parsing.Event] {
        let lines = try preprocess(yaml)
        guard !lines.isEmpty else {
            throw PureYAML.Parsing.ParseError.emptyDocument
        }

        var state = PureYAML.Parsing.EventState(
            lines: lines,
            index: 0,
            events: [
                .streamStart(mark: .start),
                .documentStart(mark: .start),
            ],
        )
        try emitBlockEvents(&state, indent: lines[0].indent)
        if state.index < lines.count {
            throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: lines[state.index].number)
        }
        let endMark = lines.last?.endMark ?? .start
        state.events.append(.documentEnd(mark: endMark))
        state.events.append(.streamEnd(mark: endMark))
        return state.events
    }
}

extension PureYAML.Parsing.Parser {
    func emitBlockEvents(
        _ state: inout PureYAML.Parsing.EventState,
        indent: Int,
    ) throws {
        guard state.index < state.lines.count else {
            state.events.append(.scalar(value: "", anchor: nil, tag: nil, style: .plain, mark: .start))
            return
        }
        let line = state.lines[state.index]
        if line.indent < indent {
            state.events.append(.scalar(value: "", anchor: nil, tag: nil, style: .plain, mark: line.mark))
            return
        }
        guard line.indent == indent else {
            throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: line.number)
        }
        if line.content.hasPrefix("-") {
            try emitSequenceEvents(&state, indent: indent)
        } else if splitMappingEntryWithOffsets(line.content) != nil {
            try emitMappingEvents(&state, indent: indent)
        } else {
            state.index += 1
            try state.events.append(scalarEvent(line.content, mark: line.mark, line: line.number))
        }
    }

    func emitSequenceEvents(
        _ state: inout PureYAML.Parsing.EventState,
        indent: Int,
    ) throws {
        let startMark = state.lines[state.index].mark
        state.events.append(.sequenceStart(anchor: nil, tag: nil, style: .block, mark: startMark))
        while state.index < state.lines.count {
            let line = state.lines[state.index]
            if line.indent < indent {
                break
            }
            guard line.indent == indent else {
                throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: line.number)
            }
            guard line.content == "-" || line.content.hasPrefix("- ") else {
                throw PureYAML.Parsing.ParseError.mixedCollectionStyles(line: line.number)
            }

            let rest = trimWithOffset(line.content, in: line.content.index(after: line.content.startIndex) ..< line.content.endIndex)
            state.index += 1
            if rest.0.isEmpty {
                if state.index < state.lines.count, state.lines[state.index].indent > indent {
                    try emitBlockEvents(&state, indent: state.lines[state.index].indent)
                } else {
                    state.events.append(.scalar(value: "", anchor: nil, tag: nil, style: .plain, mark: mark(in: line, offset: rest.1)))
                }
            } else if let entry = splitMappingEntryWithOffsets(rest.0) {
                try emitInlineMappingEvents(
                    entry,
                    line: line,
                    baseOffset: rest.1,
                    state: &state,
                    parentIndent: indent,
                )
            } else {
                try state.events.append(scalarEvent(rest.0, mark: mark(in: line, offset: rest.1), line: line.number))
            }
        }
        state.events.append(.sequenceEnd(mark: eventEndMark(state, fallback: startMark)))
    }

    func emitMappingEvents(
        _ state: inout PureYAML.Parsing.EventState,
        indent: Int,
    ) throws {
        let startMark = state.lines[state.index].mark
        state.events.append(.mappingStart(anchor: nil, tag: nil, style: .block, mark: startMark))
        try emitMappingPairEvents(&state, indent: indent)
        state.events.append(.mappingEnd(mark: eventEndMark(state, fallback: startMark)))
    }

    func emitMappingPairEvents(
        _ state: inout PureYAML.Parsing.EventState,
        indent: Int,
    ) throws {
        while state.index < state.lines.count {
            let line = state.lines[state.index]
            if line.indent < indent {
                break
            }
            guard line.indent == indent else {
                throw PureYAML.Parsing.ParseError.unexpectedIndentation(line: line.number)
            }
            guard let entry = splitMappingEntryWithOffsets(line.content) else {
                throw PureYAML.Parsing.ParseError.expectedMappingKey(line: line.number)
            }
            state.index += 1
            try emitMappingEntry(entry, line: line, baseOffset: 0, state: &state, parentIndent: indent)
        }
    }

    func emitInlineMappingEvents(
        _ entry: PureYAML.Parsing.MappingEntry,
        line: PureYAML.Parsing.Line,
        baseOffset: Int,
        state: inout PureYAML.Parsing.EventState,
        parentIndent: Int,
    ) throws {
        state.events.append(.mappingStart(anchor: nil, tag: nil, style: .block, mark: mark(in: line, offset: baseOffset + entry.keyOffset)))
        try emitMappingEntry(entry, line: line, baseOffset: baseOffset, state: &state, parentIndent: parentIndent)
        if state.index < state.lines.count, state.lines[state.index].indent > parentIndent {
            try emitMappingPairEvents(&state, indent: state.lines[state.index].indent)
        }
        state.events.append(.mappingEnd(mark: eventEndMark(state, fallback: line.endMark)))
    }

    func emitMappingEntry(
        _ entry: PureYAML.Parsing.MappingEntry,
        line: PureYAML.Parsing.Line,
        baseOffset: Int,
        state: inout PureYAML.Parsing.EventState,
        parentIndent: Int,
    ) throws {
        state.events.append(.scalar(
            value: entry.key,
            anchor: nil,
            tag: nil,
            style: entry.keyStyle,
            mark: mark(in: line, offset: baseOffset + entry.keyOffset),
        ))
        if !entry.value.isEmpty {
            try state.events.append(scalarEvent(
                entry.value,
                mark: mark(in: line, offset: baseOffset + entry.valueOffset),
                line: line.number,
            ))
        } else if state.index < state.lines.count, state.lines[state.index].indent > parentIndent {
            try emitBlockEvents(&state, indent: state.lines[state.index].indent)
        } else {
            state.events.append(.scalar(
                value: "",
                anchor: nil,
                tag: nil,
                style: .plain,
                mark: mark(in: line, offset: baseOffset + entry.valueOffset),
            ))
        }
    }

    func scalarEvent(
        _ text: String,
        mark: PureYAML.Parsing.Mark,
        line: Int,
    ) throws -> PureYAML.Parsing.Event {
        let style = scalarStyle(text)
        let value: String = switch style {
        case .plain:
            text
        case .singleQuoted:
            try parseSingleQuoted(text, line: line)
        case .doubleQuoted:
            try parseDoubleQuoted(text, line: line)
        }
        return .scalar(value: value, anchor: nil, tag: nil, style: style, mark: mark)
    }

    func mark(
        in line: PureYAML.Parsing.Line,
        offset: Int,
    ) -> PureYAML.Parsing.Mark {
        let boundedOffset = max(0, min(offset, line.content.count))
        let index = line.content.index(line.content.startIndex, offsetBy: boundedOffset)
        return PureYAML.Parsing.Mark(
            line: line.number,
            column: line.column + boundedOffset,
            index: line.index + line.content[..<index].utf8.count,
        )
    }

    func eventEndMark(
        _ state: PureYAML.Parsing.EventState,
        fallback: PureYAML.Parsing.Mark,
    ) -> PureYAML.Parsing.Mark {
        if state.index > 0, state.lines.indices.contains(state.index - 1) {
            return state.lines[state.index - 1].endMark
        }
        return fallback
    }
}
