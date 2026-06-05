import Foundation
@testable import PureYAML
import Testing

@Suite("Validation Failure Fixtures")
struct ValidationFailureFixtureTests {
    @Test("Deliberately failing YAML fixtures report exact validation descriptions", arguments: validationFailureFixtures)
    func test_deliberatelyFailingFixturesReportExactValidationDescriptions(testCase: ValidationFailureFixture) throws {
        let value = try testCase.loadValue()
        let result = testCase.validator.collect(value)

        #expect(result.issues == testCase.expectedIssues)
        #expect(result.issues.map(\.description) == testCase.expectedDescriptions)
        #expect(result.descriptionLines == testCase.expectedDescriptions)
        #expect(!result.isValid == testCase.expectedIssues.contains { $0.severity == .error })

        expectValidationError(value, using: testCase.validator) { collection in
            #expect(collection.issues == testCase.expectedIssues)
            #expect(collection.description == testCase.expectedDescriptions.joined(separator: "\n"))
        }
    }

    @Test("Warning-only failure fixture returns warnings in non-strict mode")
    func test_warningOnlyFailureFixtureReturnsWarningsInNonStrictMode() throws {
        let testCase = try #require(validationFailureFixtures.first { $0.name == "warning-only validation output" })
        let value = try testCase.loadValue()
        let warnings = try testCase.validator.validate(value, strict: false)

        #expect(warnings == testCase.expectedIssues)
        #expect(warnings.map(\.description) == testCase.expectedDescriptions)
        #expect(warnings.allSatisfy { $0.severity == .warning })
        #expect(!warnings.contains(.init(
            severity: .warning,
            reason: "Forbidden key 'deprecated' is present",
            path: .init([.key("title")]),
        )))
    }
}

let validationFailureFixtures: [ValidationFailureFixture] = [
    .init(
        name: "duplicate key validation output",
        fileName: "duplicate-keys",
        validator: .init(),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("title")]),
            ),
            .init(
                severity: .error,
                reason: "Duplicate mapping key '/users'",
                path: .init([.key("paths"), .key("/users")]),
            ),
        ],
        expectedDescriptions: [
            "error: Duplicate mapping key 'title' at $.title",
            "error: Duplicate mapping key '/users' at $.paths[\"/users\"]",
        ],
    ),
    .init(
        name: "required and forbidden validation output",
        fileName: "missing-required-and-forbidden",
        validator: .blank
            .validating(requiredRootStringKeyRule("title"))
            .validating(forbiddenMappingKeyRule("draft", severity: .error)),
        expectedIssues: [
            .init(
                severity: .error,
                reason: "Required string key 'title' is missing",
                path: .init([.key("title")]),
            ),
            .init(
                severity: .error,
                reason: "Forbidden key 'draft' is present",
                path: .init([.key("metadata"), .key("draft")]),
            ),
        ],
        expectedDescriptions: [
            "error: Required string key 'title' is missing at $.title",
            "error: Forbidden key 'draft' is present at $.metadata.draft",
        ],
    ),
    .init(
        name: "warning-only validation output",
        fileName: "warnings",
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
        expectedDescriptions: [
            "warning: Forbidden key 'deprecated' is present at $.deprecated",
            "warning: Forbidden key 'deprecated' is present at $.nested.deprecated",
        ],
    ),
]

struct ValidationFailureFixture: CustomStringConvertible {
    var name: String
    var fileName: String
    var validator: PureYAML.Validation.Validator
    var expectedIssues: [PureYAML.Validation.Issue]
    var expectedDescriptions: [String]

    var description: String {
        name
    }

    func loadValue() throws -> PureYAML.Model.Value {
        let url = try #require(Bundle.module.url(
            forResource: fileName,
            withExtension: "yaml",
            subdirectory: "Fixtures/validation-failures",
        ))
        let yaml = try String(contentsOf: url, encoding: .utf8)
        return try PureYAML.parse(yaml)
    }
}

private extension PureYAML.Validation.Result {
    var descriptionLines: [String] {
        issues.map(\.description)
    }
}
