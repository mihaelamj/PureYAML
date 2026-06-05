extension PureYAML.Parsing {
    struct Line: Equatable {
        var number: Int
        var indent: Int
        var column: Int
        var index: Int
        var content: String

        var mark: Mark {
            Mark(line: number, column: column, index: index)
        }

        var endMark: Mark {
            Mark(
                line: number,
                column: column + content.count,
                index: index + content.utf8.count,
            )
        }
    }
}
