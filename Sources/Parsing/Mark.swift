extension PureYAML.Parsing {
    struct Mark: Equatable, CustomStringConvertible {
        var line: Int
        var column: Int
        var index: Int

        init(
            line: Int,
            column: Int,
            index: Int,
        ) {
            self.line = line
            self.column = column
            self.index = index
        }

        static var start: Self {
            Self(line: 1, column: 1, index: 0)
        }

        var description: String {
            "\(line):\(column)@\(index)"
        }
    }
}
