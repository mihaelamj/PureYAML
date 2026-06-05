@testable import PureYAML
import Testing

@Suite("Model")
struct ModelTests {
    @Test("Mapping preserves insertion order")
    func mappingPreservesInsertionOrder() {
        let mapping = PureYAML.Model.Mapping([
            .init(key: "b", value: .int(2)),
            .init(key: "a", value: .int(1)),
        ])

        #expect(mapping.pairs.map(\.key) == ["b", "a"])
    }

    @Test("Mapping subscript returns first matching key")
    func mappingSubscriptReturnsFirstMatchingKey() {
        let mapping = PureYAML.Model.Mapping([
            .init(key: "name", value: .string("first")),
            .init(key: "name", value: .string("second")),
        ])

        #expect(mapping["name"] == .string("first"))
    }
}
