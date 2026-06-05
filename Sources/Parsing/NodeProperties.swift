extension PureYAML.Parsing {
    struct NodeProperties: Equatable {
        var anchor: String?
        var tag: String?
        var mark: Mark?

        static var none: Self {
            Self(anchor: nil, tag: nil, mark: nil)
        }

        mutating func mergeUnset(from other: Self) {
            anchor = anchor ?? other.anchor
            tag = tag ?? other.tag
            mark = mark ?? other.mark
        }
    }
}
