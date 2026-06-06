public extension PureYAML.Parsing {
    /// Pure-Swift YAML parser for block mappings, sequences, and common scalars.
    struct Parser: Sendable {
        public init() {}

        public func parse(_ yaml: String) throws -> PureYAML.Model.Value {
            try parseStreaming(yaml)
        }

        public func parseStream(_ yaml: String) throws -> [PureYAML.Stream.Document] {
            try parseStreamStreaming(yaml)
        }
    }
}
