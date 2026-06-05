@testable import PureYAML
import Testing

@Suite("Emitter Corpus")
struct EmitterCorpusTests {
    struct EmitterCase {
        var name: String
        var value: PureYAML.Model.Value
        var options: PureYAML.Emitting.Options
        var expected: String
        var required: [String]
        var forbidden: [String]
    }

    @Test("Emits exact corpus YAML and round trips", arguments: [
        EmitterCase(
            name: "default block mapping",
            value: .mapping(.init([
                .init(key: "name", value: .string("Example")),
                .init(key: "enabled", value: .bool(true)),
            ])),
            options: .default,
            expected: """
            name: "Example"
            enabled: true

            """,
            required: ["name: \"Example\"", "enabled: true"],
            forbidden: ["{", "["],
        ),
        EmitterCase(
            name: "plain safe strings",
            value: .mapping(.init([
                .init(key: "title", value: .string("Example title")),
                .init(key: "truth", value: .string("true")),
            ])),
            options: .init(scalarStyle: .plainWhenSafe),
            expected: """
            title: Example title
            truth: "true"

            """,
            required: ["title: Example title", "truth: \"true\""],
            forbidden: ["title: \"Example title\""],
        ),
        EmitterCase(
            name: "literal multiline block",
            value: .mapping(.init([
                .init(key: "body", value: .string("one\ntwo\n")),
            ])),
            options: .init(scalarStyle: .literalBlockWhenMultiline),
            expected: """
            body: |
              one
              two

            """,
            required: ["body: |", "  one"],
            forbidden: ["one\\ntwo"],
        ),
        EmitterCase(
            name: "flow nested collections",
            value: .mapping(.init([
                .init(key: "tags", value: .sequence([
                    .string("Swift"),
                    .string("YAML"),
                ])),
                .init(key: "meta", value: .mapping(.init([
                    .init(key: "enabled", value: .bool(true)),
                ]))),
            ])),
            options: .init(collectionStyle: .flow),
            expected: """
            {"tags": ["Swift", "YAML"], "meta": {"enabled": true}}

            """,
            required: ["{\"tags\"", "[\"Swift\", \"YAML\"]", "{\"enabled\": true}"],
            forbidden: ["\n  "],
        ),
        EmitterCase(
            name: "flow quotes unsafe plain delimiters",
            value: .sequence([
                .string("Example title"),
                .string("a, b"),
                .string("bracket [x]"),
            ]),
            options: .init(scalarStyle: .plainWhenSafe, collectionStyle: .flow),
            expected: """
            [Example title, "a, b", "bracket [x]"]

            """,
            required: ["Example title", "\"a, b\"", "\"bracket [x]\""],
            forbidden: ["\"Example title\""],
        ),
        EmitterCase(
            name: "flow quotes multiline strings",
            value: .sequence([
                .string("one\ntwo"),
            ]),
            options: .init(scalarStyle: .literalBlockWhenMultiline, collectionStyle: .flow),
            expected: """
            ["one\\ntwo"]

            """,
            required: ["\"one\\ntwo\""],
            forbidden: ["|"],
        ),
    ])
    func test_emitterCorpus(testCase: EmitterCase) throws {
        let yaml = PureYAML.dump(testCase.value, options: testCase.options)

        #expect(yaml == testCase.expected)
        for required in testCase.required {
            #expect(yaml.contains(required), "expected \(testCase.name) to contain \(required)")
        }
        for forbidden in testCase.forbidden {
            #expect(!yaml.contains(forbidden), "expected \(testCase.name) not to contain \(forbidden)")
        }
        #expect(try PureYAML.parse(yaml) == testCase.value)
    }

    @Test("Emitter corpus keeps unsupported literal block lines quoted")
    func test_unsupportedLiteralBlockLinesStayQuoted() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "colon", value: .string("one: two\nnext")),
            .init(key: "hash", value: .string("one # two\nnext")),
        ]))
        let options = PureYAML.Emitting.Options(scalarStyle: .literalBlockWhenMultiline)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        colon: "one: two\\nnext"
        hash: "one # two\\nnext"

        """)
        #expect(!yaml.contains("|"))
        #expect(yaml.contains("\\n"))
        #expect(try PureYAML.parse(yaml) == value)
    }
}
