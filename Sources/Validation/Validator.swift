public extension PureYAML.Validation {
    /// Traverses a YAML value tree and applies validation rules at each node.
    struct Validator: Sendable {
        public var rules: [Rule]

        public init(rules: [Rule] = Self.defaultRules) {
            self.rules = rules
        }

        public static var blank: Self {
            Self(rules: [])
        }

        public static var defaultRules: [Rule] {
            [.mappingKeysAreUnique]
        }

        @discardableResult
        public func validate(
            _ value: PureYAML.Model.Value,
            strict: Bool = true,
        ) throws -> [Issue] {
            let result = collect(value)
            let failures = strict ? result.issues : result.errors
            if !failures.isEmpty {
                throw Issue.Collection(failures)
            }
            return strict ? [] : result.warnings
        }

        public func collect(_ value: PureYAML.Model.Value) -> Result {
            var issues: [Issue] = []
            walk(root: value, subject: value, path: .root, issues: &issues)
            return Result(issues)
        }

        public func validating(_ rule: Rule) -> Self {
            var copy = self
            copy.rules.append(rule)
            return copy
        }
    }
}

extension PureYAML.Validation.Validator {
    func walk(
        root: PureYAML.Model.Value,
        subject: PureYAML.Model.Value,
        path: PureYAML.Validation.Path,
        issues: inout [PureYAML.Validation.Issue],
    ) {
        let context = PureYAML.Validation.Context(root: root, subject: subject, path: path)
        for rule in rules {
            issues.append(contentsOf: rule.apply(context))
        }

        switch subject {
        case let .mapping(mapping):
            for pair in mapping.pairs {
                walk(
                    root: root,
                    subject: pair.value,
                    path: path.appending(.key(pair.key)),
                    issues: &issues,
                )
            }
        case let .sequence(values):
            for index in values.indices {
                walk(
                    root: root,
                    subject: values[index],
                    path: path.appending(.index(index)),
                    issues: &issues,
                )
            }
        case .null, .bool, .int, .double, .string:
            break
        }
    }
}
