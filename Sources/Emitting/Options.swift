public extension PureYAML.Emitting {
    /// Formatting choices for emitted YAML.
    struct Options: Equatable, Sendable {
        public static let `default` = Options()

        public var scalarStyle: ScalarStyle
        public var collectionStyle: CollectionStyle

        public init(
            scalarStyle: ScalarStyle = .quoted,
            collectionStyle: CollectionStyle = .block,
        ) {
            self.scalarStyle = scalarStyle
            self.collectionStyle = collectionStyle
        }
    }
}
