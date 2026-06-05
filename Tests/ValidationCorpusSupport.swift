@testable import PureYAML

enum ValidationCorpusSource {
    case yaml(String)
    case value(PureYAML.Model.Value)

    func load() throws -> PureYAML.Model.Value {
        switch self {
        case let .yaml(yaml):
            try PureYAML.parse(yaml)
        case let .value(value):
            value
        }
    }
}

struct ValidationCorpusIssueFixture: CustomStringConvertible {
    var name: String
    var source: ValidationCorpusSource
    var validator: PureYAML.Validation.Validator
    var strict: Bool
    var expectedIssues: [PureYAML.Validation.Issue]
    var forbiddenIssues: [PureYAML.Validation.Issue]

    init(
        name: String,
        source: ValidationCorpusSource,
        validator: PureYAML.Validation.Validator,
        strict: Bool = true,
        expectedIssues: [PureYAML.Validation.Issue],
        forbiddenIssues: [PureYAML.Validation.Issue] = [],
    ) {
        self.name = name
        self.source = source
        self.validator = validator
        self.strict = strict
        self.expectedIssues = expectedIssues
        self.forbiddenIssues = forbiddenIssues
    }

    var description: String {
        name
    }
}

struct ValidationCorpusSuccessFixture: CustomStringConvertible {
    var name: String
    var source: ValidationCorpusSource
    var validator: PureYAML.Validation.Validator
    var forbiddenIssues: [PureYAML.Validation.Issue]

    init(
        name: String,
        source: ValidationCorpusSource,
        validator: PureYAML.Validation.Validator,
        forbiddenIssues: [PureYAML.Validation.Issue] = [],
    ) {
        self.name = name
        self.source = source
        self.validator = validator
        self.forbiddenIssues = forbiddenIssues
    }

    var description: String {
        name
    }
}

func requiredRootStringKeyRule(_ key: String) -> PureYAML.Validation.Rule {
    PureYAML.Validation.Rule(description: "Root requires string key '\(key)'") { context in
        guard case let .mapping(mapping) = context.subject else {
            return []
        }

        guard let value = mapping[key] else {
            return [
                PureYAML.Validation.Issue(
                    severity: .error,
                    reason: "Required string key '\(key)' is missing",
                    path: context.path.appending(.key(key)),
                ),
            ]
        }

        guard case .string = value else {
            return [
                PureYAML.Validation.Issue(
                    severity: .error,
                    reason: "Required string key '\(key)' must be a string",
                    path: context.path.appending(.key(key)),
                ),
            ]
        }

        return []
    } when: { context in
        context.path.isRoot
    }
}

func forbiddenMappingKeyRule(
    _ key: String,
    severity: PureYAML.Validation.Severity,
) -> PureYAML.Validation.Rule {
    PureYAML.Validation.Rule(description: "Mapping forbids key '\(key)'") { context in
        guard case let .mapping(mapping) = context.subject,
              mapping[key] != nil
        else {
            return []
        }

        return [
            PureYAML.Validation.Issue(
                severity: severity,
                reason: "Forbidden key '\(key)' is present",
                path: context.path.appending(.key(key)),
            ),
        ]
    } when: { context in
        if case .mapping = context.subject {
            return true
        }
        return false
    }
}

func uniqueRouteNamesRule() -> PureYAML.Validation.Rule {
    PureYAML.Validation.Rule(description: "Route names are unique") { context in
        guard case let .mapping(root) = context.subject,
              case let .sequence(routes)? = root["routes"]
        else {
            return []
        }

        var seen = Set<String>()
        var issues: [PureYAML.Validation.Issue] = []
        for index in routes.indices {
            guard case let .mapping(route) = routes[index],
                  case let .string(name)? = route["name"]
            else {
                continue
            }

            if seen.insert(name).inserted {
                continue
            }

            issues.append(.init(
                severity: .error,
                reason: "Duplicate route name '\(name)'",
                path: context.path
                    .appending(.key("routes"))
                    .appending(.index(index))
                    .appending(.key("name")),
            ))
        }
        return issues
    } when: { context in
        context.path.isRoot
    }
}
