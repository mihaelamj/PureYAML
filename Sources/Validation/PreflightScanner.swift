public extension PureYAML.Validation {
    /// Full-text diagnostic scanner that runs before YAML parsing.
    struct PreflightScanner: Sendable {
        public init() {}

        public func diagnostics(
            in yaml: String,
            file: String? = nil,
        ) -> [Diagnostic] {
            yaml.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated()
                .flatMap { lineIndex, line in
                    diagnostics(
                        in: String(line),
                        file: file,
                        line: lineIndex + 1,
                    )
                }
        }

        public func diagnostics(
            in line: String,
            file: String? = nil,
            line lineNumber: Int,
        ) -> [Diagnostic] {
            var diagnostics: [Diagnostic] = []
            if let column = firstIndentationTabColumn(in: line) {
                diagnostics.append(.preflight(
                    code: "tabIndentation",
                    file: file,
                    line: lineNumber,
                    column: column,
                    reason: "tab used for indentation; YAML indentation must use spaces",
                ))
            }
            if let column = missingMappingSpaceColumn(in: line) {
                diagnostics.append(.preflight(
                    code: "missingMappingSpace",
                    file: file,
                    line: lineNumber,
                    column: column,
                    reason: "missing space after ':' in mapping entry",
                ))
            }
            if let column = missingSequenceSpaceColumn(in: line) {
                diagnostics.append(.preflight(
                    code: "missingSequenceSpace",
                    file: file,
                    line: lineNumber,
                    column: column,
                    reason: "missing space after '-' in sequence entry",
                ))
            }
            if let column = invalidControlCharacterColumn(in: line) {
                diagnostics.append(.preflight(
                    code: "invalidControlCharacter",
                    file: file,
                    line: lineNumber,
                    column: column,
                    reason: "invalid control character in YAML source",
                ))
            }
            if let column = trailingWhitespaceColumn(in: line) {
                diagnostics.append(.preflight(
                    code: "trailingWhitespace",
                    file: file,
                    line: lineNumber,
                    column: column,
                    severity: .warning,
                    reason: "trailing whitespace",
                ))
            }
            return diagnostics
        }
    }
}

private extension PureYAML.Validation.Diagnostic {
    static func preflight(
        code: String,
        file: String?,
        line: Int,
        column: Int,
        severity: PureYAML.Validation.Severity = .error,
        reason: String,
    ) -> Self {
        .init(
            kind: .parse,
            code: code,
            severity: severity,
            file: file,
            line: line,
            column: column,
            reason: reason,
        )
    }
}

private func firstIndentationTabColumn(in line: String) -> Int? {
    for (offset, character) in line.enumerated() {
        if character == "\t" {
            return offset + 1
        }
        if character != " " {
            return nil
        }
    }
    return nil
}

private func missingMappingSpaceColumn(in line: String) -> Int? {
    guard let colonIndex = line.firstIndex(of: ":") else {
        return nil
    }
    guard isLikelyBlockMappingKey(before: colonIndex, in: line) else {
        return nil
    }

    let afterIndex = line.index(after: colonIndex)
    guard afterIndex < line.endIndex else {
        return nil
    }

    let after = line[afterIndex]
    if after == "/" {
        let secondAfterIndex = line.index(after: afterIndex)
        if secondAfterIndex < line.endIndex, line[secondAfterIndex] == "/" {
            return nil
        }
    }
    guard after != " ", after != "\t" else {
        return nil
    }
    return line.distance(from: line.startIndex, to: afterIndex) + 1
}

private func isLikelyBlockMappingKey(
    before colonIndex: String.Index,
    in line: String,
) -> Bool {
    let prefix = line[..<colonIndex]
    guard let first = prefix.firstNonWhitespace else {
        return false
    }
    guard first != "#", first != "{", first != "[", first != "\"", first != "'" else {
        return false
    }

    let key = prefix.trimmedWhitespace
    if key.hasPrefix("- ") {
        return isLikelyPlainMappingKey(String(key.dropFirst(2)))
    }
    guard !key.hasPrefix("-") else {
        return false
    }
    return isLikelyPlainMappingKey(key)
}

private func isLikelyPlainMappingKey(_ key: String) -> Bool {
    guard !key.isEmpty, !key.containsSchemeSeparator else {
        return false
    }
    return key.allSatisfy { character in
        character.isLetter
            || character.isNumber
            || character == "_"
            || character == "-"
            || character == "."
            || character == "$"
    }
}

private func missingSequenceSpaceColumn(in line: String) -> Int? {
    let trimmed = line.trimmedLeadingWhitespace
    guard trimmed.hasPrefix("-"),
          !trimmed.hasPrefix("- "),
          trimmed != "-",
          !trimmed.hasPrefix("---")
    else {
        return nil
    }

    let afterDash = trimmed.dropFirst()
    guard let firstAfterDash = afterDash.first,
          !firstAfterDash.isNumber
    else {
        return nil
    }
    guard let dashIndex = line.firstIndex(of: "-") else {
        return nil
    }
    return line.distance(from: line.startIndex, to: line.index(after: dashIndex)) + 1
}

private func invalidControlCharacterColumn(in line: String) -> Int? {
    var column = 1
    for scalar in line.unicodeScalars {
        if scalar.value < 0x20, scalar.value != 0x09, scalar.value != 0x0D {
            return column
        }
        column += 1
    }
    return nil
}

private func trailingWhitespaceColumn(in line: String) -> Int? {
    guard line.last == " " || line.last == "\t" else {
        return nil
    }

    var column = line.count
    for character in line.reversed() {
        if character == " " || character == "\t" {
            column -= 1
        } else {
            break
        }
    }
    return column + 1
}

private extension StringProtocol {
    var firstNonWhitespace: Character? {
        first { character in
            character != " " && character != "\t"
        }
    }

    var trimmedLeadingWhitespace: String {
        String(drop(while: { character in
            character == " " || character == "\t"
        }))
    }

    var trimmedWhitespace: String {
        let leadingTrimmed = drop(while: { character in
            character == " " || character == "\t"
        })
        let reversedTrailingTrimmed = leadingTrimmed.reversed().drop(while: { character in
            character == " " || character == "\t"
        })
        return String(reversedTrailingTrimmed.reversed())
    }
}

private extension String {
    var containsSchemeSeparator: Bool {
        let scalars = Array(unicodeScalars)
        guard scalars.count >= 3 else {
            return false
        }

        for index in 0 ..< scalars.count - 2 {
            let isSchemeSeparator = scalars[index] == ":"
                && scalars[index + 1] == "/"
                && scalars[index + 2] == "/"
            if isSchemeSeparator {
                return true
            }
        }
        return false
    }
}
