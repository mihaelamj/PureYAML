extension PureYAML.Parsing {
    enum ScalarStyle: String, Equatable, CustomStringConvertible {
        case plain
        case singleQuoted
        case doubleQuoted

        var description: String {
            rawValue
        }
    }
}
