extension PureYAML.Parsing {
    enum NodeKind: Equatable {
        case alias
        case mapping
        case scalar
        case sequence
    }
}
