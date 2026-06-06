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
        default:
            break
        }

        if let bool = parseBool(value) {
            return .bool(bool)
        }
        if value.hasPrefix("\"") {
            return try .string(parseDoubleQuoted(value, line: line))
        }
        if value.hasPrefix("'") {
            return try .string(parseSingleQuoted(value, line: line))
        }
        if let int = parseInteger(value), !value.contains(".") {
            return .int(int)
        }
        if value.contains(".") || value.contains("e") || value.contains("E") {
            if let double = parseDouble(value) {
                return .double(double)
            }
        }
        return .string(value)
    }

    func parseBool(_ text: String) -> Bool? {
        switch text {
        case "true", "True", "TRUE", "yes", "Yes", "YES", "on", "On", "ON":
            true
        case "false", "False", "FALSE", "no", "No", "NO", "off", "Off", "OFF":
            false
        default:
            nil
        }
    }

    func parseInteger(_ text: String) -> Int? {
        let value = removingNumericSeparators(from: text)
        let negative = value.hasPrefix("-")
        let hasSign = negative || value.hasPrefix("+")
        let unsigned = hasSign ? String(value.dropFirst()) : value

        guard !unsigned.isEmpty else {
            return nil
        }
        guard unsigned != "0" else {
            return 0
        }

        let radixPrefixes: [(prefix: String, radix: Int)] = [
            ("0x", 16),
            ("0X", 16),
            ("0b", 2),
            ("0B", 2),
            ("0o", 8),
            ("0O", 8),
            ("0", 8),
        ]

        for radixPrefix in radixPrefixes where unsigned.hasPrefix(radixPrefix.prefix) {
            let digits = String(unsigned.dropFirst(radixPrefix.prefix.count))
            guard !digits.isEmpty, let magnitude = Int(digits, radix: radixPrefix.radix) else {
                return nil
            }
            return negative ? -magnitude : magnitude
        }

        return Int(value)
    }

    func parseDouble(_ text: String) -> Double? {
        switch text {
        case ".inf", ".Inf", ".INF", "+.inf", "+.Inf", "+.INF":
            .infinity
        case "-.inf", "-.Inf", "-.INF":
            -.infinity
        case ".nan", ".NaN", ".NAN", "+.nan", "+.NaN", "+.NAN", "-.nan", "-.NaN", "-.NAN":
            .nan
        default:
            Double(removingNumericSeparators(from: text))
        }
    }

    func removingNumericSeparators(from text: String) -> String {
        text.filter { $0 != "_" }
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
        var index = inner.startIndex
        while index < inner.endIndex {
            let character = inner[index]
            if character == "\\" {
                inner.formIndex(after: &index)
                guard index < inner.endIndex else {
                    output.append("\\")
                    break
                }
                appendDoubleQuotedEscape(in: inner, index: &index, to: &output)
            } else {
                output.append(character)
                inner.formIndex(after: &index)
            }
        }
        return output
    }

    func appendDoubleQuotedEscape(
        in text: Substring,
        index: inout Substring.Index,
        to output: inout String,
    ) {
        let character = text[index]
        switch character {
        case "\"": output.append("\"")
        case "\\": output.append("\\")
        case "/": output.append("/")
        case "b": output.append("\u{08}")
        case "f": output.append("\u{0C}")
        case "n": output.append("\n")
        case "r": output.append("\r")
        case "t": output.append("\t")
        case "u":
            appendUnicodeEscape(in: text, index: &index, to: &output)
        default: output.append(character)
        }
        text.formIndex(after: &index)
    }

    func appendUnicodeEscape(
        in text: Substring,
        index: inout Substring.Index,
        to output: inout String,
    ) {
        let escapeStart = index
        guard let codeUnit = readUnicodeEscapeCodeUnit(in: text, index: &index) else {
            output.append("u")
            return
        }
        let surrogatePair = readSurrogatePairIfNeeded(high: codeUnit, in: text, index: &index)
        if let scalar = surrogatePair {
            output.unicodeScalars.append(scalar)
        } else if let scalar = UnicodeScalar(codeUnit) {
            output.unicodeScalars.append(scalar)
        } else {
            output += text[escapeStart ... index]
        }
    }

    func readSurrogatePairIfNeeded(
        high: UInt32,
        in text: Substring,
        index: inout Substring.Index,
    ) -> UnicodeScalar? {
        guard isHighSurrogate(high) else {
            return nil
        }
        return readSurrogatePair(high: high, in: text, index: &index)
    }

    func readSurrogatePair(
        high: UInt32,
        in text: Substring,
        index: inout Substring.Index,
    ) -> UnicodeScalar? {
        var probe = index
        text.formIndex(after: &probe)
        guard probe < text.endIndex, text[probe] == "\\" else {
            return nil
        }
        text.formIndex(after: &probe)
        guard probe < text.endIndex, text[probe] == "u",
              let low = readUnicodeEscapeCodeUnit(in: text, index: &probe),
              isLowSurrogate(low)
        else {
            return nil
        }
        index = probe
        let value = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
        return UnicodeScalar(value)
    }

    func readUnicodeEscapeCodeUnit(
        in text: Substring,
        index: inout Substring.Index,
    ) -> UInt32? {
        var probe = index
        text.formIndex(after: &probe)
        var hex = ""
        for _ in 0 ..< 4 {
            guard probe < text.endIndex, text[probe].isHexDigit else {
                return nil
            }
            hex.append(text[probe])
            text.formIndex(after: &probe)
        }
        index = text.index(before: probe)
        return UInt32(hex, radix: 16)
    }

    func isHighSurrogate(_ value: UInt32) -> Bool {
        (0xD800 ... 0xDBFF).contains(value)
    }

    func isLowSurrogate(_ value: UInt32) -> Bool {
        (0xDC00 ... 0xDFFF).contains(value)
    }
}
