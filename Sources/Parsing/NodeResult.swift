extension PureYAML.Parsing {
    struct NodeResult: Equatable {
        var kind: NodeKind
        var endMark: Mark
    }
}
