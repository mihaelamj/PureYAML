@testable import PureYAML
import Testing

@Suite("Validation Model")
struct ValidationModelTests {
    @Test("Validation result separates errors and warnings")
    func test_validationResultSeparatesErrorsAndWarnings() {
        let error = PureYAML.Validation.Issue(severity: .error, reason: "error")
        let warning = PureYAML.Validation.Issue(severity: .warning, reason: "warning")
        let result = PureYAML.Validation.Result([error, warning])

        #expect(result.isValid == false)
        #expect(result.errors == [error])
        #expect(result.warnings == [warning])
        #expect(!result.errors.contains(warning))
        #expect(!result.warnings.contains(error))
    }

    @Test("Validation paths describe roots keys and indexes", arguments: [
        ValidationPathCase(
            name: "root",
            path: .root,
            expectedDescription: "$",
            isRoot: true,
        ),
        ValidationPathCase(
            name: "single key",
            path: .root.appending(.key("title")),
            expectedDescription: "$.title",
            isRoot: false,
        ),
        ValidationPathCase(
            name: "nested index",
            path: .root
                .appending(.key("routes"))
                .appending(.index(1))
                .appending(.key("name")),
            expectedDescription: "$.routes[1].name",
            isRoot: false,
        ),
        ValidationPathCase(
            name: "punctuated key",
            path: .root
                .appending(.key("/users"))
                .appending(.key("get.method")),
            expectedDescription: "$./users.get.method",
            isRoot: false,
        ),
    ])
    func test_validationPathsDescribeRootsKeysAndIndexes(testCase: ValidationPathCase) {
        #expect(testCase.path.description == testCase.expectedDescription)
        #expect(testCase.path.isRoot == testCase.isRoot)
    }

    @Test("Validation issue descriptions include severity reason and path")
    func test_validationIssueDescriptionsIncludeSeverityReasonAndPath() {
        let issue = PureYAML.Validation.Issue(
            severity: .error,
            reason: "Duplicate mapping key 'title'",
            path: .init([.key("title")]),
        )

        #expect(issue.description == "error: Duplicate mapping key 'title' at $.title")
    }

    @Test("Validation issue collection describes all failures")
    func test_validationIssueCollectionDescription() {
        let collection = PureYAML.Validation.Issue.Collection([
            .init(severity: .error, reason: "first", path: .root),
            .init(severity: .warning, reason: "second", path: .init([.key("name")])),
        ])

        #expect(collection.description == """
        error: first at root
        warning: second at $.name
        """)
        #expect(collection.description.contains("error: first"))
        #expect(!collection.description.contains("info:"))
    }
}
