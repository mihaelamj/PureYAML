@testable import PureYAML
import Testing

@Suite("Validation Built-in Rules")
struct ValidationBuiltinRuleTests {
    @Test("Validates preserved value trees that ordinary YAML loaders may collapse")
    func test_validatesPreservedValueTreesThatOrdinaryYAMLLoadersMayCollapse() {
        let result = PureYAML.Validation.Validator().collect(preservedDuplicateKeyValue)

        #expect(result.issues == expectedIssues)
        #expect(result.issues.map(\.description) == [
            "error: Duplicate mapping key 'title' at $.title",
            "error: Duplicate mapping key 'items' at $.items",
            "error: Duplicate mapping key '/users' at $.paths[\"/users\"]",
            "error: Duplicate mapping key 'name.with.dot' at $.items[0][\"name.with.dot\"]",
        ])
        #expect(!result.issues.contains(.init(
            severity: .error,
            reason: "Duplicate mapping key 'paths'",
            path: .init([.key("paths")]),
        )))
        expectValidationError(preservedDuplicateKeyValue) { collection in
            #expect(collection.issues == expectedIssues)
            #expect(collection.description == expectedIssues.map(\.description).joined(separator: "\n"))
        }
    }

    @Test("Mapping key uniqueness rule is explicitly scoped to mappings")
    func test_mappingKeyUniquenessRuleIsExplicitlyScopedToMappings() {
        let scalarContext = PureYAML.Validation.Context(
            root: .string("root"),
            subject: .string("subject"),
            path: .root,
        )
        let mappingContext = PureYAML.Validation.Context(
            root: .mapping(.init()),
            subject: .mapping(.init([
                .init(key: "title", value: .string("one")),
                .init(key: "title", value: .string("two")),
            ])),
            path: .root,
        )

        #expect(!PureYAML.Validation.Rule.mappingKeysAreUnique.predicate(scalarContext))
        #expect(PureYAML.Validation.Rule.mappingKeysAreUnique.apply(scalarContext).isEmpty)
        #expect(PureYAML.Validation.Rule.mappingKeysAreUnique.predicate(mappingContext))
        #expect(PureYAML.Validation.Rule.mappingKeysAreUnique.apply(mappingContext) == [
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("title")]),
            ),
        ])
    }
}

private let preservedDuplicateKeyValue = PureYAML.Model.Value.mapping(.init([
    .init(key: "title", value: .string("First")),
    .init(key: "title", value: .string("Second")),
    .init(key: "paths", value: .mapping(.init([
        .init(key: "/users", value: .string("first")),
        .init(key: "/users", value: .string("second")),
    ]))),
    .init(key: "items", value: .sequence([
        .mapping(.init([
            .init(key: "name.with.dot", value: .string("one")),
            .init(key: "name.with.dot", value: .string("two")),
        ])),
    ])),
    .init(key: "items", value: .sequence([])),
]))

private let expectedIssues: [PureYAML.Validation.Issue] = [
    .init(
        severity: .error,
        reason: "Duplicate mapping key 'title'",
        path: .init([.key("title")]),
    ),
    .init(
        severity: .error,
        reason: "Duplicate mapping key 'items'",
        path: .init([.key("items")]),
    ),
    .init(
        severity: .error,
        reason: "Duplicate mapping key '/users'",
        path: .init([.key("paths"), .key("/users")]),
    ),
    .init(
        severity: .error,
        reason: "Duplicate mapping key 'name.with.dot'",
        path: .init([.key("items"), .index(0), .key("name.with.dot")]),
    ),
]
