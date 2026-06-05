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
        var pairs: [PureYAML.Model.Pair] = []
        while current?.isMappingEnd != true {
            let key = try composeMappingKey()
            let value = try composeNode()
            pairs.append(PureYAML.Model.Pair(key: key, value: value))
        }
        _ = try expect("mapping end") { $0.isMappingEnd }
        return .mapping(PureYAML.Model.Mapping(pairs))
    }

    mutating func composeMappingKey() throws -> String {
        guard let event = current else {
            throw unexpectedEvent(expected: "mapping key")
        }
        guard case let .scalar(value, anchor, _, _, _) = event else {
            let mark = event.mark
            throw PureYAML.Parsing.ParseError.expectedScalarKey(line: mark.line, column: mark.column)
        }
        index += 1
        store(.string(value), anchor: anchor)
        return value
    }

    func composeScalar(
        _ value: String,
        tag: String?,
        style: PureYAML.Parsing.ScalarStyle,
        mark: PureYAML.Parsing.Mark,
    ) throws -> PureYAML.Model.Value {
        if let tagged = try composeTaggedScalar(value, tag: tag, mark: mark) {
            return tagged
        }

        switch style {
        case .folded, .literal:
            return .string(value)
        case .plain:
            return try scalarParser.parseScalar(value, line: mark.line)
        case .doubleQuoted, .singleQuoted:
            return .string(value)
        }
    }

    func composeTaggedScalar(
        _ value: String,
        tag: String?,
        mark: PureYAML.Parsing.Mark,
    ) throws -> PureYAML.Model.Value? {
        guard let tag = normalizedScalarTag(tag) else {
            return nil
        }
        switch tag {
        case "tag:yaml.org,2002:str":
            return .string(value)
        case "tag:yaml.org,2002:int":
            guard let int = scalarParser.parseInteger(scalarParser.trim(value)) else {
                throw invalidTaggedScalar(tag: "tag:yaml.org,2002:int", value: value, mark: mark)
            }
            return .int(int)
        case "tag:yaml.org,2002:float":
            guard let double = scalarParser.parseDouble(scalarParser.trim(value)) else {
                throw invalidTaggedScalar(tag: "tag:yaml.org,2002:float", value: value, mark: mark)
            }
            return .double(double)
        case "tag:yaml.org,2002:bool":
            return try composeTaggedBool(value, mark: mark)
        case "tag:yaml.org,2002:null":
            return .null
        default:
            return nil
        }
    }

    func composeTaggedBool(
        _ value: String,
        mark: PureYAML.Parsing.Mark,
    ) throws -> PureYAML.Model.Value {
        guard let bool = scalarParser.parseBool(scalarParser.trim(value)) else {
            throw invalidTaggedScalar(tag: "tag:yaml.org,2002:bool", value: value, mark: mark)
        }
        return .bool(bool)
    }

    func normalizedScalarTag(_ tag: String?) -> String? {
        guard let tag else {
            return nil
        }
        if tag.hasPrefix("!<"), tag.hasSuffix(">") {
            return String(tag.dropFirst(2).dropLast())
        }
        switch tag {
        case "!!str":
            return "tag:yaml.org,2002:str"
        case "!!int":
            return "tag:yaml.org,2002:int"
        case "!!float":
            return "tag:yaml.org,2002:float"
        case "!!bool":
            return "tag:yaml.org,2002:bool"
        case "!!null":
            return "tag:yaml.org,2002:null"
        default:
            return tag
        }
    }

    func invalidTaggedScalar(
        tag: String,
        value: String,
        mark: PureYAML.Parsing.Mark,
    ) -> PureYAML.Parsing.ParseError {
        PureYAML.Parsing.ParseError.invalidTaggedScalar(
            tag: tag,
            value: value,
            line: mark.line,
            column: mark.column,
        )
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
