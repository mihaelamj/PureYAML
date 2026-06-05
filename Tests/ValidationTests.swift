@testable import PureYAML
import Testing

@Suite("Validation Rules")
struct ValidationTests {
    @Test("Valid documents produce no diagnostics", arguments: [
        ValidationValidDocumentCase(
            name: "flat mapping",
            yaml: """
            title: Example
            active: true
            retries: 3
            """,
        ),
        ValidationValidDocumentCase(
            name: "nested mapping and sequence",
            yaml: """
            routes:
              - name: Users
                methods:
                  - GET
                  - POST
              - name: Status
                methods:
                  - GET
            """,
        ),
        ValidationValidDocumentCase(
            name: "flow collections",
            yaml: """
            values: [one, 2, false, {name: Example}]
            """,
        ),
        ValidationValidDocumentCase(
            name: "anchors aliases and block scalars",
            yaml: """
            shared: &shared {title: Shared, active: true}
            first: *shared
            second:
              title: Local
            body: |
                one
                two
            """,
        ),
    ])
    func test_validDocumentsProduceNoDiagnostics(testCase: ValidationValidDocumentCase) throws {
        let value = try PureYAML.parse(testCase.yaml)
        let validator = PureYAML.Validation.Validator()
        let result = validator.collect(value)

        #expect(result == PureYAML.Validation.Result())
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
        #expect(try PureYAML.validate(value).isEmpty)
    }

    @Test("Reports duplicate mapping keys with exact diagnostics", arguments: [
        ValidationDuplicateKeyCase(
            name: "root duplicate key",
            yaml: """
            title: First
            title: Second
            """,
            expectedIssues: [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
            ],
        ),
        ValidationDuplicateKeyCase(
            name: "nested duplicate key",
            yaml: """
            routes:
              - name: Users
                name: People
            """,
            expectedIssues: [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'name'",
                    path: .init([.key("routes"), .index(0), .key("name")]),
                ),
            ],
        ),
        ValidationDuplicateKeyCase(
            name: "multiple duplicate keys preserve traversal order",
            yaml: """
            root:
              title: First
              title: Second
            routes:
              - name: Users
                name: People
              - method: GET
                method: POST
            """,
            expectedIssues: [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("root"), .key("title")]),
                ),
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'name'",
                    path: .init([.key("routes"), .index(0), .key("name")]),
                ),
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'method'",
                    path: .init([.key("routes"), .index(1), .key("method")]),
                ),
            ],
        ),
        ValidationDuplicateKeyCase(
            name: "third repeated key reports each repeated occurrence",
            yaml: """
            title: First
            title: Second
            title: Third
            """,
            expectedIssues: [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
            ],
        ),
    ])
    func test_duplicateMappingKeyDiagnostics(testCase: ValidationDuplicateKeyCase) throws {
        let value = try PureYAML.parse(testCase.yaml)
        let result = PureYAML.Validation.Validator().collect(value)

        #expect(result.issues == testCase.expectedIssues)
        #expect(result.errors == testCase.expectedIssues)
        #expect(result.warnings.isEmpty)
        expectValidationError(value) { collection in
            #expect(collection.issues == testCase.expectedIssues)
            #expect(collection.description == testCase.expectedIssues.map(\.description).joined(separator: "\n"))
        }
    }

    @Test("Blank validator disables default rules")
    func test_blankValidatorDisablesDefaultRules() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))

        #expect(try PureYAML.validate(value, using: .blank).isEmpty)
    }
}
