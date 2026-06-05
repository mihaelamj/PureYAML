extension PureYAML.Emitting.Dumper {
    func renderMapping(
        _ mapping: PureYAML.Model.Mapping,
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        guard !mapping.pairs.isEmpty else {
            return [prefix + "{}"]
        }

        return mapping.pairs.flatMap { pair in
            renderMappingPair(pair, indent: indent)
        }
    }

    func renderMappingPair(
        _ pair: PureYAML.Model.Pair,
        indent: Int,
    ) -> [String] {
        switch pair.keyNode {
        case .mapping, .sequence:
            renderComplexMappingPair(pair, indent: indent)
        case .string:
            renderStringKeyedMappingPair(pair, indent: indent)
        }
    }

    func renderStringKeyedMappingPair(
        _ pair: PureYAML.Model.Pair,
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        if let emptyCollection = renderEmptyCollectionLiteral(pair.value) {
            return [prefix + escapeKey(pair.key) + ": " + emptyCollection]
        }

        switch pair.value {
        case .mapping, .sequence:
            return [prefix + escapeKey(pair.key) + ":"] + render(pair.value, indent: indent + 2)
        default:
            return renderMappingScalarPair(pair, indent: indent)
        }
    }

    func renderComplexMappingPair(
        _ pair: PureYAML.Model.Pair,
        indent: Int,
    ) -> [String] {
        let prefix = String(repeating: " ", count: indent)
        if let emptyCollection = renderEmptyCollectionLiteral(pair.value) {
            return [prefix + "? " + pair.keyNode.flowDescription]
                + [prefix + ": " + emptyCollection]
        }

        return [prefix + "? " + pair.keyNode.flowDescription]
            + [prefix + ":"]
            + render(pair.value, indent: indent + 2)
    }

    func renderFlowMapping(_ mapping: PureYAML.Model.Mapping) -> String {
        let pairs = mapping.pairs
            .map { pair in
                "\(renderFlowKey(pair.keyNode)): \(renderFlow(pair.value))"
            }
            .joined(separator: ", ")
        return "{\(pairs)}"
    }

    func renderFlowKey(_ key: PureYAML.Model.Key) -> String {
        switch key {
        case .mapping, .sequence:
            "? \(renderFlow(key.value))"
        case let .string(value):
            quote(value)
        }
    }
}
