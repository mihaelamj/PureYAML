public extension PureYAML.Emitting {
    /// Collection rendering policy.
    enum CollectionStyle: Equatable, Sendable {
        /// Render mappings and sequences with block indentation.
        case block

        /// Render mappings and sequences with flow delimiters.
        case flow
    }
}
