extension PureYAML.Parsing {
    struct MappingEntry: Equatable {
        var key: String
        var keyStyle: ScalarStyle
        var keyOffset: Int
        var value: String
        var valueOffset: Int
    }
}
