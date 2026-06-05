extension PureYAML.Parsing {
    struct Line: Equatable {
        var number: Int
        var indent: Int
        var content: String
    }
}
