extension PureYAML.Parsing.Parser {
    func preprocess(_ yaml: String) throws -> [PureYAML.Parsing.Line] {
        var lines: [PureYAML.Parsing.Line] = []
        let rawLines = yaml.split(separator: "\n", omittingEmptySubsequences: false)
        var lineStartIndex = 0
        for offset in rawLines.indices {
            let raw = String(rawLines[offset])
            var indent = 0
            for character in raw {
                if character == " " {
                    indent += 1
                } else if character == "\t" {
                    throw PureYAML.Parsing.ParseError.tabIndentation(line: offset + 1)
                } else {
                    break
                }
            }
            let textAfterIndent = String(raw.dropFirst(indent))
            let stripped = stripComment(textAfterIndent)
            let (content, contentOffset) = trimWithOffset(stripped)
            if !content.isEmpty {
                lines.append(PureYAML.Parsing.Line(
                    number: offset + 1,
                    indent: indent,
                    column: indent + contentOffset + 1,
                    index: lineStartIndex + indent + String(stripped.prefix(contentOffset)).utf8.count,
                    content: content,
                ))
            }
            lineStartIndex += raw.utf8.count + 1
        }
        return lines
    }

    func splitMappingEntry(_ text: String) -> (key: String, value: String)? {
        guard let entry = splitMappingEntryWithOffsets(text) else {
            return nil
        }
        return (entry.key, entry.value)
    }

    func splitMappingEntryWithOffsets(_ text: String) -> PureYAML.Parsing.MappingEntry? {
        var inSingleQuote = false
        var inDoubleQuote = false
        var previousWasEscape = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\\", inDoubleQuote {
                previousWasEscape.toggle()
                index = text.index(after: index)
                continue
            }
            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"", !inSingleQuote, !previousWasEscape {
                inDoubleQuote.toggle()
            } else if character == ":", !inSingleQuote, !inDoubleQuote {
                let next = text.index(after: index)
                if next == text.endIndex || text[next] == " " {
                    let key = trimWithOffset(text, in: text.startIndex ..< index)
                    let value = next == text.endIndex
                        ? ("", text.distance(from: text.startIndex, to: text.endIndex))
                        : trimWithOffset(text, in: next ..< text.endIndex)
                    if key.0.isEmpty {
                        return nil
                    }
                    return PureYAML.Parsing.MappingEntry(
                        key: unquoteKey(key.0),
                        keyStyle: scalarStyle(key.0),
                        keyOffset: key.1,
                        value: value.0,
                        valueOffset: value.1,
                    )
                }
            }
            if character != "\\" {
                previousWasEscape = false
            }
            index = text.index(after: index)
        }
        return nil
    }

    func stripComment(_ text: String) -> String {
        var output = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var previous: Character?
        var previousWasEscape = false
        for character in text {
            if character == "\\", inDoubleQuote {
                previousWasEscape.toggle()
                output.append(character)
                previous = character
                continue
            }
            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"", !inSingleQuote, !previousWasEscape {
                inDoubleQuote.toggle()
            } else if character == "#", !inSingleQuote, !inDoubleQuote {
                if previous == nil || previous == " " {
                    break
                }
            }
            output.append(character)
            previous = character
            if character != "\\" {
                previousWasEscape = false
            }
        }
        return output
    }

    func unquoteKey(_ key: String) -> String {
        if key.count >= 2, key.first == "\"", key.last == "\"" {
            return String(key.dropFirst().dropLast())
        }
        if key.count >= 2, key.first == "'", key.last == "'" {
            return String(key.dropFirst().dropLast())
        }
        return key
    }

    func trim(_ text: String) -> String {
        trimWithOffset(text).0
    }

    func trimWithOffset(_ text: String) -> (String, Int) {
        trimWithOffset(text, in: text.startIndex ..< text.endIndex)
    }

    func trimWithOffset(
        _ text: String,
        in range: Range<String.Index>,
    ) -> (String, Int) {
        var start = text.startIndex
        var end = range.upperBound
        start = range.lowerBound
        while start < end, text[start].isWhitespace {
            start = text.index(after: start)
        }
        while end > start {
            let previous = text.index(before: end)
            if !text[previous].isWhitespace {
                break
            }
            end = previous
        }
        return (
            String(text[start ..< end]),
            text.distance(from: text.startIndex, to: start),
        )
    }
}
