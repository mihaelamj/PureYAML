extension PureYAML.Parsing {
    enum EventStreamComposerMode {
        case singleDocument
        case stream
    }

    struct EventStreamComposedNode {
        var value: PureYAML.Model.Value
        var mappingKey: PureYAML.Parsing.EventComposer.ComposedMappingKey
        var mark: PureYAML.Parsing.Mark
        var sequenceItems: [EventStreamComposedNode] = []
    }

    enum EventStreamContainerKind {
        case sequence
        case mapping
    }

    struct EventStreamContainer {
        var kind: EventStreamContainerKind
        var anchor: String?
        var values: [EventStreamComposedNode] = []
        var mergeSources: [[PureYAML.Model.Pair]] = []
        var localPairs: [PureYAML.Model.Pair] = []
        var pendingKey: PureYAML.Parsing.EventComposer.ComposedMappingKey?
        var mark: PureYAML.Parsing.Mark
    }

    struct EventStreamComposer {
        let scalarParser: Parser
        let mode: EventStreamComposerMode
        var anchors: [String: PureYAML.Model.Value] = [:]
        var containers: [EventStreamContainer] = []
        var documentValues: [PureYAML.Model.Value] = []
        var currentDocumentValue: PureYAML.Model.Value?
        var didSeeStreamStart = false
        var didSeeStreamEnd = false

        init(
            scalarParser: Parser,
            mode: EventStreamComposerMode,
        ) {
            self.scalarParser = scalarParser
            self.mode = mode
        }

        mutating func consume(_ event: PureYAML.Parsing.Event) throws {
            switch event {
            case .streamStart:
                didSeeStreamStart = true
            case .streamEnd:
                didSeeStreamEnd = true
            case let .documentStart(mark):
                try startDocument(mark: mark)
            case let .documentEnd(mark):
                try endDocument(mark: mark)
            case let .scalar(value, anchor, tag, style, mark):
                try consumeScalar(value, anchor: anchor, tag: tag, style: style, mark: mark)
            case let .alias(anchor, mark):
                try consumeAlias(anchor, mark: mark)
            case let .sequenceStart(anchor, _, _, mark):
                containers.append(.init(kind: .sequence, anchor: anchor, mark: mark))
            case let .sequenceEnd(mark):
                try completeSequence(mark: mark)
            case let .mappingStart(anchor, _, _, mark):
                containers.append(.init(kind: .mapping, anchor: anchor, mark: mark))
            case let .mappingEnd(mark):
                try completeMapping(mark: mark)
            }
        }

        mutating func composedValue() throws -> PureYAML.Model.Value {
            guard didSeeStreamStart, didSeeStreamEnd else {
                throw unexpectedEvent(expected: "complete YAML stream", mark: .start)
            }
            guard documentValues.count == 1, let value = documentValues.first else {
                throw unexpectedEvent(expected: "single YAML document", mark: .start)
            }
            return value
        }

        mutating func composedStream() throws -> [PureYAML.Stream.Document] {
            guard didSeeStreamStart, didSeeStreamEnd else {
                throw unexpectedEvent(expected: "complete YAML stream", mark: .start)
            }
            return documentValues.enumerated().map { index, value in
                PureYAML.Stream.Document(index: index, value: value)
            }
        }
    }
}

private extension PureYAML.Parsing.EventStreamComposer {
    mutating func startDocument(mark: PureYAML.Parsing.Mark) throws {
        guard containers.isEmpty else {
            throw unexpectedEvent(expected: "document content end", mark: mark)
        }
        if mode == .singleDocument, !documentValues.isEmpty {
            throw PureYAML.Parsing.ParseError.unsupportedMultiDocumentStream(line: mark.line)
        }
        anchors = [:]
        currentDocumentValue = nil
    }

    mutating func endDocument(mark: PureYAML.Parsing.Mark) throws {
        guard containers.isEmpty else {
            throw unexpectedEvent(expected: "document content end", mark: mark)
        }
        documentValues.append(currentDocumentValue ?? .null)
        currentDocumentValue = nil
    }

    mutating func consumeScalar(
        _ value: String,
        anchor: String?,
        tag: String?,
        style: PureYAML.Parsing.ScalarStyle,
        mark: PureYAML.Parsing.Mark,
    ) throws {
        let model = try scalarParser.composeScalarValue(value, tag: tag, style: style, mark: mark)
        if let anchor {
            anchors[anchor] = .string(value)
        }
        try complete(.init(
            value: model,
            mappingKey: .init(
                keyNode: .string(value),
                scalarValue: value,
                tag: scalarParser.normalizedTag(tag),
                style: style,
            ),
            mark: mark,
        ))
    }

    mutating func consumeAlias(
        _ anchor: String,
        mark: PureYAML.Parsing.Mark,
    ) throws {
        guard let value = anchors[anchor] else {
            throw PureYAML.Parsing.ParseError.undefinedAlias(
                anchor: anchor,
                line: mark.line,
                column: mark.column,
            )
        }
        try complete(.init(
            value: value,
            mappingKey: .init(
                keyNode: PureYAML.Model.Key(value: value),
                scalarValue: nil,
                tag: nil,
                style: nil,
            ),
            mark: mark,
        ))
    }

    mutating func completeSequence(mark: PureYAML.Parsing.Mark) throws {
        guard let container = containers.popLast(), container.kind == .sequence else {
            throw unexpectedEvent(expected: "sequence start", mark: mark)
        }
        let value = PureYAML.Model.Value.sequence(container.values.map(\.value))
        store(value, anchor: container.anchor)
        try complete(.init(
            value: value,
            mappingKey: .init(
                keyNode: PureYAML.Model.Key(value: value),
                scalarValue: nil,
                tag: nil,
                style: nil,
            ),
            mark: container.mark,
            sequenceItems: container.values,
        ))
    }

    mutating func completeMapping(mark: PureYAML.Parsing.Mark) throws {
        guard let container = containers.popLast(), container.kind == .mapping else {
            throw unexpectedEvent(expected: "mapping start", mark: mark)
        }
        guard container.pendingKey == nil else {
            throw unexpectedEvent(expected: "mapping value", mark: mark)
        }
        let pairs = mergedPairs(
            from: container.mergeSources,
            localPairs: container.localPairs,
        )
        let value = PureYAML.Model.Value.mapping(.init(pairs))
        store(value, anchor: container.anchor)
        try complete(.init(
            value: value,
            mappingKey: .init(
                keyNode: PureYAML.Model.Key(value: value),
                scalarValue: nil,
                tag: nil,
                style: nil,
            ),
            mark: container.mark,
        ))
    }

    mutating func complete(_ node: PureYAML.Parsing.EventStreamComposedNode) throws {
        guard !containers.isEmpty else {
            currentDocumentValue = node.value
            return
        }

        switch containers[containers.count - 1].kind {
        case .sequence:
            containers[containers.count - 1].values.append(node)
        case .mapping:
            try completeMappingNode(node)
        }
    }

    mutating func completeMappingNode(_ node: PureYAML.Parsing.EventStreamComposedNode) throws {
        let index = containers.count - 1
        guard let key = containers[index].pendingKey else {
            containers[index].pendingKey = node.mappingKey
            return
        }

        if key.isMergeKey {
            try containers[index].mergeSources.append(contentsOf: mergeSources(
                from: node,
            ))
        } else {
            containers[index].localPairs.append(.init(keyNode: key.keyNode, value: node.value))
        }
        containers[index].pendingKey = nil
    }

    mutating func store(
        _ value: PureYAML.Model.Value,
        anchor: String?,
    ) {
        guard let anchor else {
            return
        }
        anchors[anchor] = value
    }

    func mergeSources(
        from node: PureYAML.Parsing.EventStreamComposedNode,
    ) throws -> [[PureYAML.Model.Pair]] {
        switch node.value {
        case let .mapping(mapping):
            return [mapping.pairs]
        case let .sequence(values):
            guard !node.sequenceItems.isEmpty else {
                return try values.map { value in
                    guard case let .mapping(mapping) = value else {
                        throw invalidMergeValue(mark: node.mark)
                    }
                    return mapping.pairs
                }
            }
            return try values.enumerated().map { index, value in
                let mark = node.sequenceItems[index].mark
                guard case let .mapping(mapping) = value else {
                    throw invalidMergeValue(mark: mark)
                }
                return mapping.pairs
            }
        case .bool, .double, .int, .null, .string:
            throw invalidMergeValue(mark: node.mark)
        }
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

    func invalidMergeValue(
        mark: PureYAML.Parsing.Mark,
    ) -> PureYAML.Parsing.ParseError {
        PureYAML.Parsing.ParseError.invalidMergeValue(
            line: mark.line,
            column: mark.column,
        )
    }

    func unexpectedEvent(
        expected: String,
        mark: PureYAML.Parsing.Mark,
    ) -> PureYAML.Parsing.ParseError {
        PureYAML.Parsing.ParseError.unexpectedEvent(
            expected: expected,
            actual: "streaming event",
            line: mark.line,
            column: mark.column,
        )
    }
}
