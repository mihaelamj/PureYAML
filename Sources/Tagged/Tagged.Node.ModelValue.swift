public extension PureYAML.Tagged.Node {
    /// Converts a tagged node into a model value while explicitly erasing tags.
    var modelValueErasingTags: PureYAML.Model.Value {
        switch self {
        case let .mapping(mapping):
            .mapping(.init(mapping.pairs.map { pair in
                .init(key: pair.key, value: pair.value.modelValueErasingTags)
            }))
        case let .scalar(scalar):
            scalar.value
        case let .sequence(sequence):
            .sequence(sequence.values.map(\.modelValueErasingTags))
        }
    }
}

public extension PureYAML.Tagged.Constructor where Output == PureYAML.Model.Value {
    /// Explicit fallback constructor that preserves order and duplicates while erasing tags.
    static var modelValueErasingTags: Self {
        Self().fallingBackTo { node, _ in
            node.modelValueErasingTags
        }
    }
}
