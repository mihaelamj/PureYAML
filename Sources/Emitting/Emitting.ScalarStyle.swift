public extension PureYAML.Emitting {
    /// Scalar rendering policy.
    enum ScalarStyle: Equatable, Sendable {
        /// Always render strings as double-quoted scalars.
        case quoted

        /// Render strings as plain scalars only when that is unambiguous.
        case plainWhenSafe
    }
}
