extension PureYAML.Parsing.EventComposer {
    struct ComposedMappingKey {
        var keyNode: PureYAML.Model.Key
        var scalarValue: String?
        var tag: String?
        var style: PureYAML.Parsing.ScalarStyle?

        var isMergeKey: Bool {
            guard let scalarValue else {
                return false
            }
            return tag == "tag:yaml.org,2002:merge"
                || (tag == nil && style == .plain && scalarValue == "<<")
        }
    }

    mutating func composeMergeSources() throws -> [[PureYAML.Model.Pair]] {
        guard let event = current else {
            throw unexpectedEvent(expected: "merge value")
        }
        switch event {
        case .sequenceStart:
            return try composeMergeSequenceSources()
        default:
            let value = try composeNode()
            return try mergeSources(from: value, mark: event.mark)
        }
    }

    mutating func composeMergeSequenceSources() throws -> [[PureYAML.Model.Pair]] {
        _ = try expect("merge sequence start") { event in
            if case .sequenceStart = event {
                return true
            }
            return false
        }
        var sources: [[PureYAML.Model.Pair]] = []
        while current?.isSequenceEnd != true {
            guard let event = current else {
                throw unexpectedEvent(expected: "merge sequence item")
            }
            let value = try composeNode()
            try sources.append(mergeSequenceItemSource(from: value, mark: event.mark))
        }
        _ = try expect("merge sequence end") { $0.isSequenceEnd }
        return sources
    }

    func mergeSources(
        from value: PureYAML.Model.Value,
        mark: PureYAML.Parsing.Mark,
    ) throws -> [[PureYAML.Model.Pair]] {
        switch value {
        case let .mapping(mapping):
            return [mapping.pairs]
        case let .sequence(values):
            return try values.map { value in
                guard case let .mapping(mapping) = value else {
                    throw invalidMergeValue(mark: mark)
                }
                return mapping.pairs
            }
        case .bool, .double, .int, .null, .string:
            throw invalidMergeValue(mark: mark)
        }
    }

    func mergeSequenceItemSource(
        from value: PureYAML.Model.Value,
        mark: PureYAML.Parsing.Mark,
    ) throws -> [PureYAML.Model.Pair] {
        guard case let .mapping(mapping) = value else {
            throw invalidMergeValue(mark: mark)
        }
        return mapping.pairs
    }

    func mergedPairs(
        from mergeSources: [[PureYAML.Model.Pair]],
        localPairs: [PureYAML.Model.Pair],
    ) -> [PureYAML.Model.Pair] {
        guard !mergeSources.isEmpty else {
            return localPairs
        }

        let localKeys = Set(localPairs.map(\.keyNode))
        var inheritedKeys = Set<PureYAML.Model.Key>()
        var inheritedPairs: [PureYAML.Model.Pair] = []
        for source in mergeSources {
            var sourceKeys = Set<PureYAML.Model.Key>()
            for pair in source {
                guard !localKeys.contains(pair.keyNode),
                      !inheritedKeys.contains(pair.keyNode)
                else {
                    continue
                }
                inheritedPairs.append(pair)
                sourceKeys.insert(pair.keyNode)
            }
            inheritedKeys.formUnion(sourceKeys)
        }
        return inheritedPairs + localPairs
    }

    func invalidMergeValue(mark: PureYAML.Parsing.Mark) -> PureYAML.Parsing.ParseError {
        PureYAML.Parsing.ParseError.invalidMergeValue(
            line: mark.line,
            column: mark.column,
        )
    }
}
