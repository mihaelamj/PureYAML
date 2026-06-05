public extension PureYAML.Emitting {
    /// Formatting choices for emitted YAML.
    struct Options: Equatable, Sendable {
        public static let `default` = Options()

        public var scalarStyle: ScalarStyle

        public init(scalarStyle: ScalarStyle = .quoted) {
            self.scalarStyle = scalarStyle
        }
    }
}
