extension PureYAML.Parsing {
    enum BlockScalarChomping: String, Equatable, CustomStringConvertible {
        case clip
        case strip

        var description: String {
            rawValue
        }
    }
}
