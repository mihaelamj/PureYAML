@testable import PureYAML
import Testing

@Suite("Validation Corpus")
struct ValidationCorpusTests {
    @Test("Fixture corpus succeeds without diagnostics", arguments: validationCorpusSuccessFixtures)
    func test_fixtureCorpusSucceedsWithoutDiagnostics(testCase: ValidationCorpusSuccessFixture) throws {
        let value = try testCase.source.load()
        let result = testCase.validator.collect(value)

        #expect(result == PureYAML.Validation.Result())
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
        #expect(try PureYAML.validate(value, using: testCase.validator).isEmpty)

        for forbiddenIssue in testCase.forbiddenIssues {
            #expect(!result.issues.contains(forbiddenIssue))
        }
    }

    @Test("Fixture corpus reports exact validation issues", arguments: validationCorpusIssueFixtures)
    func test_fixtureCorpusReportsExactValidationIssues(testCase: ValidationCorpusIssueFixture) throws {
        let value = try testCase.source.load()
        let result = testCase.validator.collect(value)

        #expect(result.issues == testCase.expectedIssues)
        #expect(result.issues.map(\.description) == testCase.expectedIssues.map(\.description))

        for forbiddenIssue in testCase.forbiddenIssues {
            #expect(!result.issues.contains(forbiddenIssue))
        }

        expectValidationError(value, using: testCase.validator, strict: testCase.strict) { collection in
            #expect(collection.issues == testCase.expectedIssues)
            #expect(collection.description == testCase.expectedIssues.map(\.description).joined(separator: "\n"))
        }
    }

    @Test("Fixture corpus returns warnings in non-strict mode")
    func test_fixtureCorpusReturnsWarningsInNonStrictMode() throws {
        let fixture = validationCorpusIssueFixtures.first {
            $0.name == "strict warning fixture throws exact warning collection"
        }

        let testCase = try #require(fixture)
        let value = try testCase.source.load()
        let warnings = try PureYAML.validate(value, using: testCase.validator, strict: false)

        #expect(warnings == testCase.expectedIssues)
        #expect(warnings.allSatisfy { $0.severity == .warning })
        #expect(!warnings.contains(.init(
            severity: .warning,
            reason: "Forbidden key 'deprecated' is present",
            path: .init([.key("title")]),
        )))
    }

    @Test("Fixture corpus preserves traversal order")
    func test_fixtureCorpusPreservesTraversalOrder() throws {
        let value = try PureYAML.parse(
            """
            root:
              mode: legacy
            list:
              - mode: legacy
            """,
        )
        let validator = PureYAML.Validation.Validator.blank
            .validating(traceRule(label: "first"))
            .validating(forbiddenMappingKeyRule("mode", severity: .warning))
            .validating(legacyModeRule(severity: .error))

        let result = validator.collect(value)

        #expect(result.issues.map(\.description) == [
            "warning: first at root at root",
            "warning: first at $.root at $.root",
            "warning: Forbidden key 'mode' is present at $.root.mode",
            "warning: first at $.root.mode at $.root.mode",
            "error: Legacy mode is not allowed at $.root.mode",
            "warning: first at $.list at $.list",
            "warning: first at $.list[0] at $.list[0]",
            "warning: Forbidden key 'mode' is present at $.list[0].mode",
            "warning: first at $.list[0].mode at $.list[0].mode",
            "error: Legacy mode is not allowed at $.list[0].mode",
        ])
    }
}
