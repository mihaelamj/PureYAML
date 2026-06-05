public extension PureYAML.Validation.Rule {
    /// Reports duplicate keys in any mapping.
    static var mappingKeysAreUnique: Self {
        Self(description: "Mapping keys are unique") { context in
            guard case let .mapping(mapping) = context.subject else {
                return []
            }

            var seen = Set<PureYAML.Model.Key>()
            var issues: [PureYAML.Validation.Issue] = []
            for pair in mapping.pairs {
                if seen.insert(pair.keyNode).inserted {
                    continue
                } else {
                    issues.append(PureYAML.Validation.Issue(
                        severity: .error,
                        reason: "Duplicate mapping key '\(pair.keyNode.description)'",
                        path: context.path.appending(pair.keyNode.pathComponent),
                    ))
                }
            }
            return issues
        } when: { context in
            if case .mapping = context.subject {
                return true
            }
            return false
        }
    }
}

extension PureYAML.Model.Key {
    var pathComponent: PureYAML.Validation.Path.Component {
        switch self {
        case let .string(value):
            .key(value)
        case .mapping, .sequence:
            .complexKey(self)
        }
    }
}
