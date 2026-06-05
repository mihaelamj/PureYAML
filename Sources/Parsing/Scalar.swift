extension PureYAML.Parsing.Parser {
    func scalarStyle(_ text: String) -> PureYAML.Parsing.ScalarStyle {
        if text.hasPrefix("\"") {
            return .doubleQuoted
        }
        if text.hasPrefix("'") {
            return .singleQuoted
        }
        return .plain
    }

    func parseScalar(
        _ text: String,
        line: Int,
    ) throws -> PureYAML.Model.Value {
        let value = trim(text)
        switch value {
        case "", "~", "null", "Null", "NULL":
            return .null
        case "true", "True", "TRUE":
            return .bool(true)
        case "false", "False", "FALSE":
            return .bool(false)
        default:
            break
        }

        if value.hasPrefix("\"") {
            return try .string(parseDoubleQuoted(value, line: line))
        }
        if value.hasPrefix("'") {
            return try .string(parseSingleQuoted(value, line: line))
        }
        if let int = Int(value), !value.contains(".") {
            return .int(int)
        }
        if value.contains(".") || value.contains("e") || value.contains("E") {
            if let double = Double(value) {
                return .double(double)
            }
        }
        return .string(value)
    }

    func parseSingleQuoted(
        _ text: String,
        line: Int,
    ) throws -> String {
        guard text.count >= 2, text.last == "'" else {
            throw PureYAML.Parsing.ParseError.unterminatedQuotedString(line: line)
        }
        let inner = text.dropFirst().dropLast()
        var output = ""
        var iterator = inner.makeIterator()
        while let character = iterator.next() {
            if character == "'", let next = iterator.next() {
                if next == "'" {
                    output.append("'")
                } else {
                    output.append(character)
                    output.append(next)
                }
            } else {
                output.append(character)
            }
        }
        return output
    }

    func parseDoubleQuoted(
        _ text: String,
        line: Int,
    ) throws -> String {
        guard text.count >= 2, text.last == "\"" else {
            throw PureYAML.Parsing.ParseError.unterminatedQuotedString(line: line)
        }
        let inner = text.dropFirst().dropLast()
        var output = ""
        var escaping = false
        for character in inner {
            if escaping {
                appendDoubleQuotedEscape(character, to: &output)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                output.append(character)
            }
        }
        if escaping {
            output.append("\\")
        }
        return output
    }

    func appendDoubleQuotedEscape(
        _ character: Character,
        to output: inout String,
    ) {
        switch character {
        case "\"": output.append("\"")
        case "\\": output.append("\\")
        case "/": output.append("/")
        case "n": output.append("\n")
        case "r": output.append("\r")
        case "t": output.append("\t")
        default: output.append(character)
        }
    }
}
