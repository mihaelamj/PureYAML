extension PureYAML.Parsing.TokenEventParser {
    mutating func parseFlowSequence(
        properties: PureYAML.Parsing.NodeProperties,
    ) throws -> PureYAML.Parsing.NodeResult {
        let start = try expect("flow sequence start") { kind in
            if case .flowSequenceStart = kind {
                return true
            }
            return false
        }
        let startMark = properties.mark ?? start.mark
        var endMark = start.endMark
        events.append(.sequenceStart(
            anchor: properties.anchor,
            tag: properties.tag,
            style: .flow,
            mark: startMark,
        ))
        while cursor.current != nil {
            if case .flowSequenceEnd = cursor.current?.kind {
                let end = try expect("flow sequence end") { kind in
                    if case .flowSequenceEnd = kind {
                        return true
                    }
                    return false
                }
                endMark = end.endMark
                events.append(.sequenceEnd(mark: endMark))
                return PureYAML.Parsing.NodeResult(kind: .sequence, endMark: endMark)
            }
            if case .flowEntry = cursor.current?.kind {
                _ = cursor.advance()
                continue
            }
            endMark = try parseNode().endMark
            if cursor.current?.kind.isFlowTerminator == false {
                throw unexpectedToken(expected: "flow entry or flow sequence end")
            }
        }
        throw unexpectedToken(expected: "flow sequence end")
    }

    mutating func parseFlowMapping(
        properties: PureYAML.Parsing.NodeProperties,
    ) throws -> PureYAML.Parsing.NodeResult {
        let start = try expect("flow mapping start") { kind in
            if case .flowMappingStart = kind {
                return true
            }
            return false
        }
        let startMark = properties.mark ?? start.mark
        var endMark = start.endMark
        events.append(.mappingStart(
            anchor: properties.anchor,
            tag: properties.tag,
            style: .flow,
            mark: startMark,
        ))
        while cursor.current != nil {
            if case .flowMappingEnd = cursor.current?.kind {
                let end = try expect("flow mapping end") { kind in
                    if case .flowMappingEnd = kind {
                        return true
                    }
                    return false
                }
                endMark = end.endMark
                events.append(.mappingEnd(mark: endMark))
                return PureYAML.Parsing.NodeResult(kind: .mapping, endMark: endMark)
            }
            if case .flowEntry = cursor.current?.kind {
                _ = cursor.advance()
                continue
            }
            endMark = try parseFlowMappingPair().endMark
            if cursor.current?.kind.isFlowTerminator == false {
                throw unexpectedToken(expected: "flow entry or flow mapping end")
            }
        }
        throw unexpectedToken(expected: "flow mapping end")
    }

    mutating func parseFlowMappingPair() throws -> PureYAML.Parsing.NodeResult {
        if cursor.current?.kind.isMappingKey == true {
            return try parseMappingPair()
        }

        _ = try parseNode()
        let valueIndicator = try expect("mapping value") { kind in
            if case .mappingValue = kind {
                return true
            }
            return false
        }

        let properties = consumeProperties()
        guard properties != .none || cursor.current?.kind.isFlowTerminator == false else {
            let mark = valueIndicator.endMark
            events.append(.scalar(value: "", anchor: nil, tag: nil, style: .plain, mark: mark))
            return PureYAML.Parsing.NodeResult(kind: .scalar, endMark: mark)
        }
        return try parseNode(properties: properties)
    }
}
