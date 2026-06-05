public extension PureYAML.Tagged.Rule {
    /// Reports unsupported built-in tags and built-in tags applied to the wrong node kind.
    static var builtInTagsAreSupportedAndKindConsistent: Self {
        Self(description: "Built-in tags are supported and kind-consistent") { context in
            var issues: [PureYAML.Validation.Issue] = []
            if case let .mapping(mapping) = context.subject {
                issues.append(contentsOf: mapping.pairs.compactMap { pair in
                    keyTagIssue(for: pair, at: context.path.appending(.key(pair.key)))
                })
            }

            guard let tag = context.subject.tag, tag.isBuiltIn else {
                return issues
            }

            if let expectedKind = tag.expectedKind, expectedKind != context.subject.kind {
                issues.append(
                    PureYAML.Validation.Issue(
                        severity: .error,
                        reason: "Tag '\(tag.rawValue)' expects a \(expectedKind) node, found \(context.subject.kind)",
                        path: context.path,
                    ),
                )
                return issues
            }

            if !tag.isSupportedBuiltInTag {
                issues.append(
                    PureYAML.Validation.Issue(
                        severity: .error,
                        reason: "Unsupported built-in tag '\(tag.rawValue)'",
                        path: context.path,
                    ),
                )
            }

            return issues
        } when: { context in
            if context.subject.tag?.isBuiltIn == true {
                return true
            }
            if case let .mapping(mapping) = context.subject {
                return mapping.pairs.contains { $0.keyTag?.isBuiltIn == true }
            }
            return false
        }
    }

    static func keyTagIssue(
        for pair: PureYAML.Tagged.Pair,
        at path: PureYAML.Validation.Path,
    ) -> PureYAML.Validation.Issue? {
        guard let tag = pair.keyTag, tag.isBuiltIn else {
            return nil
        }
        if tag == .merge, pair.key == "<<" {
            return nil
        }
        if tag == .merge {
            return PureYAML.Validation.Issue(
                severity: .error,
                reason: "Tag '\(tag.rawValue)' is only supported on '<<' mapping keys",
                path: path,
            )
        }
        if let expectedKind = tag.expectedKind, expectedKind != .scalar {
            return PureYAML.Validation.Issue(
                severity: .error,
                reason: "Tag '\(tag.rawValue)' expects a scalar mapping key",
                path: path,
            )
        }
        guard tag.isSupportedBuiltInTag else {
            return PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag '\(tag.rawValue)' on mapping key",
                path: path,
            )
        }
        return nil
    }
}
