extension PureYAML.Parsing {
    struct NodeProperties: Equatable {
        var anchor: String?
        var tag: String?
        var mark: Mark?

        static var none: Self {
            Self(anchor: nil, tag: nil, mark: nil)
        }
    }
}
