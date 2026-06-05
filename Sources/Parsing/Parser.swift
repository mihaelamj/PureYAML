public extension PureYAML.Parsing {
    /// Pure-Swift YAML parser for block mappings, sequences, and common scalars.
    struct Parser: Sendable {
        public init() {}

        public func parse(_ yaml: String) throws -> PureYAML.Model.Value {
            let events = try parseEvents(yaml)
            var composer = PureYAML.Parsing.EventComposer(events: events, scalarParser: self)
            return try composer.compose()
        }

        public func parseStream(_ yaml: String) throws -> [PureYAML.Stream.Document] {
            let events = try parseEvents(yaml)
            var composer = PureYAML.Parsing.EventComposer(events: events, scalarParser: self)
            return try composer.composeStream()
        }
    }
}
