extension PureYAML.Parsing {
    struct Reader {
        private let source: String
        private let utf8: String.UTF8View
        private var position: String.Index
        private var utf8Position: String.UTF8View.Index
        private var line: Int
        private var column: Int
        private var utf8Index: Int

        init(_ source: String) {
            self.source = source
            utf8 = source.utf8
            position = source.startIndex
            utf8Position = source.utf8.startIndex
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
            switch utf8[utf8Position] {
            case 13:
                advanceCarriageReturn()
                line += 1
                column = 1
            case 10:
                advanceASCIICharacter()
                line += 1
                column = 1
            case 0 ..< 128:
                advanceASCIICharacter()
                column += 1
            default:
                advanceExtendedCharacter()
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

        private mutating func advanceASCIICharacter() {
            position = source.index(after: position)
            utf8Position = utf8.index(after: utf8Position)
            utf8Index += 1
        }

        private mutating func advanceCarriageReturn() {
            position = source.index(after: position)
            utf8Position = utf8.index(after: utf8Position)
            utf8Index += 1
            guard utf8Position < utf8.endIndex, utf8[utf8Position] == 10 else {
                return
            }
            utf8Position = utf8.index(after: utf8Position)
            utf8Index += 1
            if position < source.endIndex, source[position] == "\n" {
                position = source.index(after: position)
            }
        }

        private mutating func advanceExtendedCharacter() {
            position = source.index(after: position)
            guard let nextUTF8Position = position.samePosition(in: utf8) else {
                utf8Index += String(source[source.index(before: position)]).utf8.count
                return
            }
            utf8Index += utf8.distance(from: utf8Position, to: nextUTF8Position)
            utf8Position = nextUTF8Position
        }
    }
}
