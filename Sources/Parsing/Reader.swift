extension PureYAML.Parsing {
    struct Reader {
        private let source: String
        private var position: String.Index
        private var line: Int
        private var column: Int
        private var utf8Index: Int

        init(_ source: String) {
            self.source = source
            position = source.startIndex
            line = 1
            column = 1
            utf8Index = 0
        }

        var isAtEnd: Bool {
            position >= source.endIndex
        }

        var mark: Mark {
            Mark(line: line, column: column, index: utf8Index)
        }

        func peek(offset: Int = 0) -> Character? {
            var cursor = position
            for _ in 0 ..< offset {
                guard cursor < source.endIndex else {
                    return nil
                }
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex else {
                return nil
            }
            return source[cursor]
        }

        @discardableResult
        mutating func advance() -> Character? {
            guard position < source.endIndex else {
                return nil
            }
            let character = source[position]
            position = source.index(after: position)
            utf8Index += String(character).utf8.count
            if character == "\r\n" {
                line += 1
                column = 1
            } else if character == "\r" {
                if position < source.endIndex, source[position] == "\n" {
                    position = source.index(after: position)
                    utf8Index += 1
                }
                line += 1
                column = 1
            } else if character == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
            return character
        }

        mutating func consume(while predicate: (Character) -> Bool) -> String {
            var output = ""
            while let character = peek(), predicate(character) {
                output.append(character)
                advance()
            }
            return output
        }
    }
}
