extension PureYAML.Tagged {
    struct EventComposer {
        var events: [PureYAML.Parsing.Event]
        var index: Int
        var anchors: [String: PureYAML.Tagged.Node]
        let scalarParser: PureYAML.Parsing.Parser

        init(
            events: [PureYAML.Parsing.Event],
            scalarParser: PureYAML.Parsing.Parser,
        ) {
            self.events = events
            index = 0
            anchors = [:]
            self.scalarParser = scalarParser
        }

        mutating func compose() throws -> PureYAML.Tagged.Node {
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
            _ = try expect("stream end") { event in
                if case .streamEnd = event {
                    return true
                }
                return false
            }
            return value
        }

        mutating func composeStream() throws -> [PureYAML.Tagged.Document] {
            _ = try expect("stream start") { event in
                if case .streamStart = event {
                    return true
                }
                return false
            }

            var documents: [PureYAML.Tagged.Document] = []
            while current?.isStreamEnd != true {
                _ = try expect("document start") { event in
                    if case .documentStart = event {
                        return true
                    }
                    return false
                }
                anchors = [:]
                let node = try composeNode()
                _ = try expect("document end") { event in
                    if case .documentEnd = event {
                        return true
                    }
                    return false
                }
                documents.append(.init(index: documents.count, node: node))
            }

            _ = try expect("stream end") { event in
                if case .streamEnd = event {
                    return true
                }
                return false
            }
            return documents
        }
    }
}

extension PureYAML.Tagged.EventComposer {
    mutating func composeNode() throws -> PureYAML.Tagged.Node {
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
        case let .mappingStart(anchor, tag, _, _):
            let value = try composeMapping(tag: tag)
            store(value, anchor: anchor)
            return value
        case let .scalar(value, anchor, tag, style, mark):
            index += 1
            let scalar = try PureYAML.Tagged.Scalar(
                rawValue: value,
                value: scalarParser.composeScalarValue(
                    value,
                    tag: tag,
                    style: style,
                    mark: mark,
                ),
                tag: .normalized(tag),
            )
            let node = PureYAML.Tagged.Node.scalar(scalar)
            store(node, anchor: anchor)
            return node
        case let .sequenceStart(anchor, tag, _, _):
            let value = try composeSequence(tag: tag)
            store(value, anchor: anchor)
            return value
        default:
            throw unexpectedEvent(expected: "YAML node")
        }
    }

    mutating func composeSequence(tag: String?) throws -> PureYAML.Tagged.Node {
        _ = try expect("sequence start") { event in
            if case .sequenceStart = event {
                return true
            }
            return false
        }
        var values: [PureYAML.Tagged.Node] = []
        while current?.isSequenceEnd != true {
            try values.append(composeNode())
        }
        _ = try expect("sequence end") { $0.isSequenceEnd }
        return .sequence(.init(values: values, tag: .normalized(tag)))
    }

    mutating func composeMapping(tag: String?) throws -> PureYAML.Tagged.Node {
        _ = try expect("mapping start") { event in
            if case .mappingStart = event {
                return true
            }
            return false
        }
        var pairs: [PureYAML.Tagged.Pair] = []
        while current?.isMappingEnd != true {
            let key = try composeMappingKey()
            let value = try composeNode()
            pairs.append(.init(key: key.value, keyTag: key.tag, value: value))
        }
        _ = try expect("mapping end") { $0.isMappingEnd }
        return .mapping(.init(pairs: pairs, tag: .normalized(tag)))
    }

    mutating func composeMappingKey() throws -> ComposedMappingKey {
        guard let event = current else {
            throw unexpectedEvent(expected: "mapping key")
        }
        guard case let .scalar(value, anchor, tag, style, mark) = event else {
            let mark = event.mark
            throw PureYAML.Parsing.ParseError.expectedScalarKey(line: mark.line, column: mark.column)
        }
        index += 1
        let scalar = try PureYAML.Tagged.Scalar(
            rawValue: value,
            value: scalarParser.composeScalarValue(value, tag: tag, style: style, mark: mark),
            tag: .normalized(tag),
        )
        store(.scalar(scalar), anchor: anchor)
        return ComposedMappingKey(value: value, tag: .normalized(tag))
    }
}

extension PureYAML.Tagged.EventComposer {
    struct ComposedMappingKey {
        var value: String
        var tag: PureYAML.Tagged.Tag?
    }

    var current: PureYAML.Parsing.Event? {
        guard events.indices.contains(index) else {
            return nil
        }
        return events[index]
    }

    mutating func store(
        _ value: PureYAML.Tagged.Node,
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
}
