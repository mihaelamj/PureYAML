public extension PureYAML.Stream {
    /// A parsed YAML document inside a stream.
    struct Document: Equatable, Sendable {
        public var index: Int
        public var value: PureYAML.Model.Value

        public init(
            index: Int,
            value: PureYAML.Model.Value,
        ) {
            self.index = index
            self.value = value
        }
    }
}
