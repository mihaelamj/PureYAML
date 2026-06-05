@testable import PureYAML
import Testing

@Suite("Arbitrary Any API Decision")
struct ArbitraryAnyDecisionTests {
    @Test("Model values preserve diagnostics that dictionary-shaped projections erase")
    func test_modelValuesPreserveDiagnosticsThatDictionaryShapedProjectionsErase() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
            .init(key: "slug", value: .string("example")),
        ]))

        guard case let .mapping(mapping) = value else {
            recordIssue("expected mapping fixture")
            return
        }

        let projectedDictionary = Dictionary(
            mapping.pairs.map { ($0.key, $0.value) },
            uniquingKeysWith: { _, second in second },
        )
        let validationResult = PureYAML.Validation.Validator().collect(value)

        #expect(mapping.pairs.map(\.key) == ["title", "title", "slug"])
        #expect(projectedDictionary.keys.sorted() == ["slug", "title"])
        #expect(projectedDictionary["title"] == .string("Second"))
        #expect(validationResult.issues == [
            .init(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("title")]),
            ),
        ])
    }
}
