@testable import PureYAML

let validationCorpusSuccessFixtures: [ValidationCorpusSuccessFixture] = [
    .init(
        name: "required title present and draft absent",
        source: .yaml("""
        title: Example
        slug: example
        """),
        validator: .blank
            .validating(requiredRootStringKeyRule("title"))
            .validating(forbiddenMappingKeyRule("draft", severity: .error)),
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Required string key 'title' is missing",
                path: .init([.key("title")]),
            ),
            .init(
                severity: .error,
                reason: "Forbidden key 'draft' is present",
                path: .init([.key("draft")]),
            ),
        ],
    ),
    .init(
        name: "alias resolves to valid anchored mapping",
        source: .yaml("""
        shared: &shared {title: Shared, slug: shared}
        first: *shared
        second:
          title: Local
          slug: local
        """),
        validator: .init(),
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("shared"), .key("title")]),
            ),
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("first"), .key("title")]),
            ),
        ],
    ),
    .init(
        name: "punctuation-heavy direct value has unique keys",
        source: .value(.mapping(.init([
            .init(key: "/users/{id}", value: .string("show")),
            .init(key: "name.with.dot", value: .string("safe")),
            .init(key: "", value: .string("empty")),
        ]))),
        validator: .init(),
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Duplicate mapping key '/users/{id}'",
                path: .init([.key("/users/{id}")]),
            ),
            .init(
                severity: .error,
                reason: "Duplicate mapping key ''",
                path: .init([.key("")]),
            ),
        ],
    ),
]

let validationCorpusIssueFixtures: [ValidationCorpusIssueFixture] = [
    .init(
        name: "required root string key reports exact missing path",
        source: .yaml("""
        slug: missing-title
        """),
        validator: .blank.validating(requiredRootStringKeyRule("title")),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Required string key 'title' is missing",
                path: .init([.key("title")]),
            ),
        ],
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Required string key 'slug' is missing",
                path: .init([.key("slug")]),
            ),
        ],
    ),
    .init(
        name: "required root string key reports exact type mismatch path",
        source: .yaml("""
        title: 42
        """),
        validator: .blank.validating(requiredRootStringKeyRule("title")),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Required string key 'title' must be a string",
                path: .init([.key("title")]),
            ),
        ],
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Required string key 'title' is missing",
                path: .init([.key("title")]),
            ),
        ],
    ),
    .init(
        name: "forbidden key reports required absence failure",
        source: .yaml("""
        title: Example
        draft: true
        """),
        validator: .blank
            .validating(requiredRootStringKeyRule("title"))
            .validating(forbiddenMappingKeyRule("draft", severity: .error)),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Forbidden key 'draft' is present",
                path: .init([.key("draft")]),
            ),
        ],
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Required string key 'title' is missing",
                path: .init([.key("title")]),
            ),
        ],
    ),
    .init(
        name: "duplicate route names report only repeated occurrence",
        source: .yaml("""
        routes:
          - name: /users
            method: GET
          - name: /users
            method: POST
          - name: /status
            method: GET
        """),
        validator: .blank.validating(uniqueRouteNamesRule()),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Duplicate route name '/users'",
                path: .init([.key("routes"), .index(1), .key("name")]),
            ),
        ],
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Duplicate route name '/users'",
                path: .init([.key("routes"), .index(0), .key("name")]),
            ),
            .init(
                severity: .error,
                reason: "Duplicate route name '/status'",
                path: .init([.key("routes"), .index(2), .key("name")]),
            ),
        ],
    ),
    .init(
        name: "aliases preserve duplicate keys for validation",
        source: .yaml("""
        shared: &shared {title: First, title: Second}
        article: *shared
        """),
        validator: .init(),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("shared"), .key("title")]),
            ),
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("article"), .key("title")]),
            ),
        ],
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'article'",
                path: .init([.key("article")]),
            ),
        ],
    ),
    .init(
        name: "merged mappings preserve duplicate local keys for validation",
        source: .yaml("""
        defaults: &defaults {retries: 1}
        service: {<<: *defaults, name: API, name: Backend}
        """),
        validator: .init(),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'name'",
                path: .init([.key("service"), .key("name")]),
            ),
        ],
        forbiddenIssues: [
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'retries'",
                path: .init([.key("service"), .key("retries")]),
            ),
            .init(
                severity: .error,
                reason: "Duplicate mapping key '<<'",
                path: .init([.key("service"), .key("<<")]),
            ),
        ],
    ),
    .init(
        name: "punctuation-heavy direct duplicate keys escape paths exactly",
        source: .value(.mapping(.init([
            .init(key: "paths", value: .mapping(.init([
                .init(key: "/users/{id}", value: .string("first")),
                .init(key: "/users/{id}", value: .string("second")),
                .init(key: "", value: .string("empty one")),
                .init(key: "", value: .string("empty two")),
                .init(key: "quote\"slash\\line\nnext\tend", value: .string("one")),
                .init(key: "quote\"slash\\line\nnext\tend", value: .string("two")),
            ]))),
        ]))),
        validator: .init(),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Duplicate mapping key '/users/{id}'",
                path: .init([.key("paths"), .key("/users/{id}")]),
            ),
            .init(
                severity: .error,
                reason: "Duplicate mapping key ''",
                path: .init([.key("paths"), .key("")]),
            ),
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'quote\"slash\\line\nnext\tend'",
                path: .init([.key("paths"), .key("quote\"slash\\line\nnext\tend")]),
            ),
        ],
    ),
    .init(
        name: "strict warning fixture throws exact warning collection",
        source: .yaml("""
        title: Example
        deprecated: true
        nested:
          deprecated: true
        """),
        validator: .blank.validating(forbiddenMappingKeyRule("deprecated", severity: .warning)),
        expectedIssues: [
            .init(
                severity: .warning,
                reason: "Forbidden key 'deprecated' is present",
                path: .init([.key("deprecated")]),
            ),
            .init(
                severity: .warning,
                reason: "Forbidden key 'deprecated' is present",
                path: .init([.key("nested"), .key("deprecated")]),
            ),
        ],
        forbiddenIssues: [
            .init(
                severity: .warning,
                reason: "Forbidden key 'deprecated' is present",
                path: .init([.key("title")]),
            ),
        ],
    ),
]
