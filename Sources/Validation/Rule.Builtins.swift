public extension PureYAML.Validation.Rule {
    /// Reports duplicate keys in any mapping.
    static var mappingKeysAreUnique: Self {
        Self(description: "Mapping keys are unique") { context in
            guard case let .mapping(mapping) = context.subject else {
                return []
            }

            var seen: [String] = []
            var issues: [PureYAML.Validation.Issue] = []
            for pair in mapping.pairs {
                if seen.contains(pair.key) {
                    issues.append(PureYAML.Validation.Issue(
                        severity: .error,
                        reason: "Duplicate mapping key '\(pair.key)'",
                        path: context.path.appending(.key(pair.key)),
                    ))
                } else {
                    seen.append(pair.key)
                }
            }
            return issues
        }
    }
}
