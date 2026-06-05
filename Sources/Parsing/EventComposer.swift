extension PureYAML.Parsing {
    struct EventComposer {
        var events: [Event]
        var index: Int
        var anchors: [String: PureYAML.Model.Value]
        let scalarParser: Parser

        init(
            events: [Event],
            scalarParser: Parser,
        ) {
            self.events = events
            index = 0
            anchors = [:]
            self.scalarParser = scalarParser
        }

        mutating func compose() throws -> PureYAML.Model.Value {
            _ = try expect("stream start") { event in
                if case .streamStart = event {
                    return true
                }
                return false
            }
            _ = try expect("document start") { event in
                if case .documentStart = event {
                    return true
                }
                return false
            }
            let value = try composeNode()
            _ = try expect("document end") { event in
                if case .documentEnd = event {
                    return true
                }
                return false
            }
            if case let .documentStart(mark)? = current {
                throw PureYAML.Parsing.ParseError.unsupportedMultiDocumentStream(line: mark.line)
            }
            _ = try expectStreamEnd()
            return value
        }

        mutating func composeStream() throws -> [PureYAML.Stream.Document] {
            _ = try expect("stream start") { event in
                if case .streamStart = event {
                    return true
                }
                return false
            }

            var documents: [PureYAML.Stream.Document] = []
            while current?.isStreamEnd != true {
                _ = try expect("document start") { event in
                    if case .documentStart = event {
                        return true
                    }
                    return false
                }
                anchors = [:]
                let value = try composeNode()
                _ = try expect("document end") { event in
                    if case .documentEnd = event {
                        return true
                    }
                    return false
                }
                documents.append(.init(index: documents.count, value: value))
            }

            _ = try expectStreamEnd()
            return documents
        }
    }
}

extension PureYAML.Parsing.EventComposer {
    mutating func composeNode() throws -> PureYAML.Model.Value {
        guard let event = current else {
            throw unexpectedEvent(expected: "YAML node")
        }

        switch event {
        case let .alias(anchor, mark):
            index += 1
            guard let value = anchors[anchor] else {
                throw PureYAML.Parsing.ParseError.undefinedAlias(
                    anchor: anchor,
                    line: mark.line,
                    column: mark.column,
                )
            }
            return value
        case let .mappingStart(anchor, _, _, _):
            let value = try composeMapping()
            store(value, anchor: anchor)
            return value
        case let .scalar(value, anchor, tag, style, mark):
            index += 1
            let model = try composeScalar(
                value,
                tag: tag,
                style: style,
                mark: mark,
            )
            store(model, anchor: anchor)
            return model
        case let .sequenceStart(anchor, _, _, _):
            let value = try composeSequence()
            store(value, anchor: anchor)
            return value
        default:
            throw unexpectedEvent(expected: "YAML node")
        }
    }

    mutating func composeSequence() throws -> PureYAML.Model.Value {
        _ = try expect("sequence start") { event in
            if case .sequenceStart = event {
                return true
            }
            return false
        }
        var values: [PureYAML.Model.Value] = []
        while current?.isSequenceEnd != true {
            try values.append(composeNode())
        }
        _ = try expect("sequence end") { $0.isSequenceEnd }
        return .sequence(values)
    }

    mutating func composeMapping() throws -> PureYAML.Model.Value {
        _ = try expect("mapping start") { event in
            if case .mappingStart = event {
                return true
            }
            return false
        }
        var mergeSources: [[PureYAML.Model.Pair]] = []
        var localPairs: [PureYAML.Model.Pair] = []
        while current?.isMappingEnd != true {
            let key = try composeMappingKey()
            if key.isMergeKey {
                try mergeSources.append(contentsOf: composeMergeSources())
            } else {
                let value = try composeNode()
                localPairs.append(PureYAML.Model.Pair(keyNode: key.keyNode, value: value))
            }
        }
        _ = try expect("mapping end") { $0.isMappingEnd }
        let pairs = mergedPairs(from: mergeSources, localPairs: localPairs)
        return .mapping(PureYAML.Model.Mapping(pairs))
    }

    mutating func composeMappingKey() throws -> ComposedMappingKey {
        guard let event = current else {
            throw unexpectedEvent(expected: "mapping key")
        }
        guard case let .scalar(value, anchor, tag, style, _) = event else {
            let value = try composeNode()
            return ComposedMappingKey(
                keyNode: PureYAML.Model.Key(value: value),
                scalarValue: nil,
                tag: nil,
                style: nil,
            )
        }
        index += 1
        store(.string(value), anchor: anchor)
        return ComposedMappingKey(
            keyNode: .string(value),
            scalarValue: value,
            tag: scalarParser.normalizedTag(tag),
            style: style,
        )
    }

    func composeScalar(
        _ value: String,
        tag: String?,
        style: PureYAML.Parsing.ScalarStyle,
        mark: PureYAML.Parsing.Mark,
    ) throws -> PureYAML.Model.Value {
        try scalarParser.composeScalarValue(value, tag: tag, style: style, mark: mark)
    }
}

extension PureYAML.Parsing.EventComposer {
    var current: PureYAML.Parsing.Event? {
        guard events.indices.contains(index) else {
            return nil
        }
        return events[index]
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

    mutating func expect(
        _ expected: String,
        matching: (PureYAML.Parsing.Event) -> Bool,
    ) throws -> PureYAML.Parsing.Event {
        guard let event = current else {
            throw unexpectedEvent(expected: expected)
        }
        guard matching(event) else {
            throw unexpectedEvent(expected: expected)
        }
        index += 1
        return event
    }

    func unexpectedEvent(expected: String) -> PureYAML.Parsing.ParseError {
        let mark = current?.mark ?? events.last?.mark ?? .start
        return PureYAML.Parsing.ParseError.unexpectedEvent(
            expected: expected,
            actual: current?.description ?? "end of events",
            line: mark.line,
            column: mark.column,
        )
    }

    mutating func expectStreamEnd() throws -> PureYAML.Parsing.Event {
        try expect("stream end") { event in
            if case .streamEnd = event {
                return true
            }
            return false
        }
    }
}
