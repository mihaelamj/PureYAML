public extension PureYAML.Validation {
    /// Location of a value inside a YAML document.
    struct Path: Equatable, Sendable, CustomStringConvertible {
        public var components: [Component]

        public init(_ components: [Component] = []) {
            self.components = components
        }

        public static var root: Self {
            Self()
        }

        public var isRoot: Bool {
            components.isEmpty
        }

        public func appending(_ component: Component) -> Self {
            var copy = components
            copy.append(component)
            return Self(copy)
        }

        public var description: String {
            guard !components.isEmpty else {
                return "$"
            }
            return components.reduce("$") { partial, component in
                partial + component.description
            }
        }
    }
}
