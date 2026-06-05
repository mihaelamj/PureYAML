@testable import PureYAML
import Testing

@Suite("Dumper Empty Collections")
struct DumperEmptyCollectionTests {
    @Test("Dumps empty collections")
    func test_emptyCollections() throws {
        #expect(PureYAML.dump(.mapping(.init())) == "{}\n")
        #expect(PureYAML.dump(.sequence([])) == "[]\n")
        #expect(try PureYAML.parse(PureYAML.dump(.mapping(.init()))) == .mapping(.init()))
        #expect(try PureYAML.parse(PureYAML.dump(.sequence([]))) == .sequence([]))

        let nested = PureYAML.Model.Value.mapping(.init([
            .init(key: "mapping", value: .mapping(.init())),
            .init(key: "sequence", value: .sequence([])),
            .init(key: "items", value: .sequence([
                .sequence([]),
                .mapping(.init()),
            ])),
        ]))

        #expect(PureYAML.dump(nested) == """
        mapping: {}
        sequence: []
        items:
          - []
          - {}

        """)
        #expect(try PureYAML.parse(PureYAML.dump(nested)) == nested)

        let options = PureYAML.Emitting.Options(collectionStyle: .flow)
        #expect(PureYAML.dump(.mapping(.init()), options: options) == "{}\n")
        #expect(PureYAML.dump(.sequence([]), options: options) == "[]\n")
    }
}
