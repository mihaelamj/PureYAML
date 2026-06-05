extension PureYAML.Parsing {
    enum CollectionStyle: String, Equatable, CustomStringConvertible {
        case block
        case flow

        var description: String {
            rawValue
        }
    }
}
