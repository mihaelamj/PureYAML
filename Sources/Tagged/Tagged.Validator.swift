public extension PureYAML.Tagged {
    /// Traverses a tag-preserving YAML node tree and applies validation rules.
    struct Validator: Sendable {
        public var rules: [Rule]

        public init(rules: [Rule] = Self.defaultRules) {
            self.rules = rules
        }

        public static var blank: Self {
            Self(rules: [])
        }

        public static var defaultRules: [Rule] {
            [.builtInTagsAreSupportedAndKindConsistent]
        }

        @discardableResult
        public func validate(
            _ node: Node,
            strict: Bool = true,
        ) throws -> [PureYAML.Validation.Issue] {
            let result = collect(node)
            let failures = strict ? result.issues : result.errors
            if !failures.isEmpty {
                throw PureYAML.Validation.Issue.Collection(failures)
            }
            return strict ? [] : result.warnings
        }

        public func collect(_ node: Node) -> PureYAML.Validation.Result {
            var issues: [PureYAML.Validation.Issue] = []
            walk(root: node, subject: node, path: .root, issues: &issues)
            return PureYAML.Validation.Result(issues)
        }

        @discardableResult
        public func validate(
            _ documents: [Document],
            strict: Bool = true,
        ) throws -> [PureYAML.Stream.Issue] {
            let result = collect(documents)
            let failures = strict ? result.issues : result.errors
            if !failures.isEmpty {
                throw PureYAML.Stream.Issue.Collection(failures)
            }
            return strict ? [] : result.warnings
        }

        public func collect(_ documents: [Document]) -> PureYAML.Stream.Result {
            var issues: [PureYAML.Stream.Issue] = []
            for document in documents {
                let result = collect(document.node)
                issues.append(contentsOf: result.issues.map { issue in
                    PureYAML.Stream.Issue(documentIndex: document.index, issue: issue)
                })
            }
            return PureYAML.Stream.Result(issues)
        }

        public func validating(_ rule: Rule) -> Self {
            var copy = self
            copy.rules.append(rule)
            return copy
        }
    }
}

extension PureYAML.Tagged.Validator {
    func walk(
        root: PureYAML.Tagged.Node,
        subject: PureYAML.Tagged.Node,
        path: PureYAML.Validation.Path,
        issues: inout [PureYAML.Validation.Issue],
    ) {
        let context = PureYAML.Tagged.Context(root: root, subject: subject, path: path)
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
        case let .sequence(sequence):
            for index in sequence.values.indices {
                walk(
                    root: root,
                    subject: sequence.values[index],
                    path: path.appending(.index(index)),
                    issues: &issues,
                )
            }
        case .scalar:
            break
        }
    }
}
