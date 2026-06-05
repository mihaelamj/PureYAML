extension PureYAML.Parsing {
    enum BlockScalarStyle: String, Equatable, CustomStringConvertible {
        case literal
        case folded

        var description: String {
            rawValue
        }
    }
}
