public extension PureYAML.Parsing.Parser {
    /// Parses a YAML document into a tag-preserving node tree.
    func parseTagged(_ yaml: String) throws -> PureYAML.Tagged.Node {
        let events = try parseEvents(yaml)
        var composer = PureYAML.Tagged.EventComposer(events: events, scalarParser: self)
        return try composer.compose()
    }

    /// Parses a YAML stream into tag-preserving indexed documents.
    func parseTaggedStream(_ yaml: String) throws -> [PureYAML.Tagged.Document] {
        let events = try parseEvents(yaml)
        var composer = PureYAML.Tagged.EventComposer(events: events, scalarParser: self)
        return try composer.composeStream()
    }
}

public extension PureYAML {
    /// Parses a YAML document into a tag-preserving node tree.
    static func parseTagged(_ yaml: String) throws -> Tagged.Node {
        try Parsing.Parser().parseTagged(yaml)
    }

    /// Parses a YAML stream into tag-preserving indexed documents.
    static func parseTaggedStream(_ yaml: String) throws -> [Tagged.Document] {
        try Parsing.Parser().parseTaggedStream(yaml)
    }
}
