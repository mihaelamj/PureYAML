extension PureYAML.Parsing.Parser {
    func preprocess(_ yaml: String) throws -> [PureYAML.Parsing.Line] {
        var lines: [PureYAML.Parsing.Line] = []
        let rawLines = yaml.split(separator: "\n", omittingEmptySubsequences: false)
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
            let content = trim(stripComment(String(raw.dropFirst(indent))))
            if !content.isEmpty {
                lines.append(PureYAML.Parsing.Line(number: offset + 1, indent: indent, content: content))
            }
        }
        return lines
    }

    func splitMappingEntry(_ text: String) -> (key: String, value: String)? {
        var inSingleQuote = false
        var inDoubleQuote = false
        var previousWasEscape = false
        let characters = Array(text)
        for index in characters.indices {
            let character = characters[index]
            if character == "\\", inDoubleQuote {
                previousWasEscape.toggle()
                continue
            }
            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
            } else if character == "\"", !inSingleQuote, !previousWasEscape {
                inDoubleQuote.toggle()
            } else if character == ":", !inSingleQuote, !inDoubleQuote {
                let next = characters.index(after: index)
                if next == characters.endIndex || characters[next] == " " {
                    let key = trim(String(characters[..<index]))
                    let value = next == characters.endIndex ? "" : trim(String(characters[next...]))
                    if key.isEmpty {
                        return nil
                    }
                    return (unquoteKey(key), value)
                }
            }
            if character != "\\" {
                previousWasEscape = false
            }
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
        var start = text.startIndex
        var end = text.endIndex
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
        return String(text[start ..< end])
    }
}
