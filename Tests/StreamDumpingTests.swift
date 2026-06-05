@testable import PureYAML
import Testing

@Suite("Stream Dumping")
struct StreamDumpingTests {
    @Test("Dumps stream documents with explicit starts exactly")
    func test_dumpsStreamDocumentsWithExplicitStartsExactly() throws {
        let documents = [
            PureYAML.Stream.Document(index: 4, value: .mapping(.init([
                .init(key: "title", value: .string("First")),
            ]))),
            PureYAML.Stream.Document(index: 2, value: .sequence([
                .string("Swift"),
                .string("YAML"),
            ])),
        ]
        let yaml = PureYAML.dump(documents)

        #expect(yaml == """
        ---
        title: "First"
        ---
        - "Swift"
        - "YAML"

        """)
        #expect(yaml.hasPrefix("---\n"))
        #expect(documentStartCount(in: yaml) == 2)
        #expect(!yaml.contains("document[4]"))
        #expect(try PureYAML.parseStream(yaml).map(\.value) == documents.map(\.value))
        #expect(try PureYAML.validate(PureYAML.parseStream(yaml)).isEmpty)
    }

    @Test("Dumps stream documents in array order rather than index order")
    func test_dumpsStreamDocumentsInArrayOrderRatherThanIndexOrder() throws {
        let documents = [
            PureYAML.Stream.Document(index: 10, value: .string("third")),
            PureYAML.Stream.Document(index: 0, value: .string("first")),
            PureYAML.Stream.Document(index: 5, value: .string("second")),
        ]
        let yaml = PureYAML.dump(documents)

        #expect(yaml == """
        ---
        "third"
        ---
        "first"
        ---
        "second"

        """)
        #expect(try PureYAML.parseStream(yaml).map(\.value) == [
            .string("third"),
            .string("first"),
            .string("second"),
        ])
        #expect(!yaml.hasPrefix("---\n\"first\""))
    }

    @Test("Dumps empty stream as an empty string")
    func test_dumpsEmptyStreamAsEmptyString() {
        #expect(PureYAML.dump([PureYAML.Stream.Document]()) == "")
    }

    @Test("Dumps stream null documents exactly")
    func test_dumpsStreamNullDocumentsExactly() throws {
        let documents = [
            PureYAML.Stream.Document(index: 0, value: .null),
            PureYAML.Stream.Document(index: 1, value: .mapping(.init([
                .init(key: "empty", value: .null),
            ]))),
        ]
        let yaml = PureYAML.dump(documents)

        #expect(yaml == """
        ---
        null
        ---
        empty: null

        """)
        #expect(try PureYAML.parseStream(yaml) == [
            .init(index: 0, value: .null),
            .init(index: 1, value: .mapping(.init([
                .init(key: "empty", value: .null),
            ]))),
        ])
    }

    @Test("Dumps stream documents with flow output")
    func test_dumpsStreamDocumentsWithFlowOutput() throws {
        let documents = [
            PureYAML.Stream.Document(index: 0, value: .mapping(.init([
                .init(key: "tags", value: .sequence([
                    .string("Swift"),
                    .string("YAML"),
                ])),
            ]))),
            PureYAML.Stream.Document(index: 1, value: .sequence([
                .int(1),
                .int(2),
            ])),
        ]
        let options = PureYAML.Emitting.Options(collectionStyle: .flow)
        let yaml = PureYAML.dump(documents, options: options)

        #expect(yaml == """
        ---
        {"tags": ["Swift", "YAML"]}
        ---
        [1, 2]

        """)
        #expect(!yaml.contains("\n  - "))
        #expect(try PureYAML.parseStream(yaml).map(\.value) == documents.map(\.value))
    }

    @Test("Dumps stream documents with literal block scalar output")
    func test_dumpsStreamDocumentsWithLiteralBlockScalarOutput() throws {
        let documents = [
            PureYAML.Stream.Document(index: 0, value: .mapping(.init([
                .init(key: "body", value: .string("one\ntwo\n")),
            ]))),
            PureYAML.Stream.Document(index: 1, value: .string("alpha\nbeta")),
        ]
        let options = PureYAML.Emitting.Options(scalarStyle: .literalBlockWhenMultiline)
        let yaml = PureYAML.dump(documents, options: options)

        #expect(yaml == """
        ---
        body: |
          one
          two
        ---
        |-
          alpha
          beta

        """)
        #expect(yaml.contains("body: |"))
        #expect(yaml.contains("|-\n  alpha"))
        #expect(!yaml.contains("one\\ntwo"))
        #expect(try PureYAML.parseStream(yaml).map(\.value) == documents.map(\.value))
    }

    @Test("Dumps stream documents with complex mapping keys")
    func test_dumpsStreamDocumentsWithComplexMappingKeys() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(
                keyNode: .sequence([
                    .string("Detroit Tigers"),
                    .string("Chicago Cubs"),
                ]),
                value: .sequence([
                    .string("2001-07-23"),
                ]),
            ),
        ]))
        let documents = [
            PureYAML.Stream.Document(index: 0, value: value),
        ]
        let yaml = PureYAML.dump(documents)

        #expect(yaml == """
        ---
        ? ["Detroit Tigers", "Chicago Cubs"]
        :
          - "2001-07-23"

        """)
        #expect(yaml.contains("? [\"Detroit Tigers\", \"Chicago Cubs\"]"))
        #expect(try PureYAML.parseStream(yaml).map(\.value) == [value])
    }
}

private func documentStartCount(in yaml: String) -> Int {
    yaml.split(separator: "\n", omittingEmptySubsequences: false)
        .count(where: { $0 == "---" })
}
