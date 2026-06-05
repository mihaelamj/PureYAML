@testable import PureYAML
import Testing

@Suite("Dumper")
struct DumperTests {
    @Test("Dumps scalar mapping values")
    func test_scalarMappingValues() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "missing", value: .null),
            .init(key: "enabled", value: .bool(true)),
            .init(key: "retries", value: .int(3)),
            .init(key: "ratio", value: .double(3.1)),
            .init(key: "title", value: .string("Example")),
        ]))

        #expect(PureYAML.dump(value) == """
        missing: null
        enabled: true
        retries: 3
        ratio: 3.1
        title: "Example"

        """)
    }

    @Test("Escapes scalar strings and mapping keys")
    func test_escapesScalarStringsAndMappingKeys() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "a:b", value: .string("quote \" slash \\ tab\t")),
            .init(key: "hash#key", value: .string("line\nnext")),
        ]))

        #expect(PureYAML.dump(value) == """
        "a:b": "quote \\" slash \\\\ tab\\t"
        "hash#key": "line\\nnext"

        """)
        #expect(!PureYAML.dump(value).contains("quote \" slash \\ tab\t"))
        #expect(!PureYAML.dump(value).contains("line\nnext"))
    }

    @Test("Dumps nested sequences and mappings")
    func test_nestedSequencesAndMappings() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "servers", value: .sequence([
                .mapping(.init([
                    .init(key: "url", value: .string("/")),
                    .init(key: "description", value: .string("Default")),
                ])),
            ])),
        ]))

        #expect(PureYAML.dump(value) == """
        servers:
          -
            url: "/"
            description: "Default"

        """)
    }

    @Test("Dumps top-level sequences")
    func test_topLevelSequences() {
        let value = PureYAML.Model.Value.sequence([
            .string("one"),
            .int(2),
            .bool(false),
        ])

        #expect(PureYAML.dump(value) == """
        - "one"
        - 2
        - false

        """)
    }

    @Test("Dumps round-trippable YAML")
    func test_roundTrippableYaml() throws {
        let original = PureYAML.Model.Value.mapping(.init([
            .init(key: "paths", value: .mapping(.init([
                .init(key: "/users", value: .mapping(.init([
                    .init(key: "tags", value: .sequence([
                        .string("Users"),
                        .string("Public"),
                    ])),
                ]))),
            ]))),
        ]))

        #expect(try PureYAML.parse(PureYAML.dump(original)) == original)
    }

    @Test("Dumps empty collections")
    func test_emptyCollections() {
        #expect(PureYAML.dump(.mapping(.init())) == "\n")
        #expect(PureYAML.dump(.sequence([])) == "\n")
    }

    @Test("Dumps plain strings only when selected and safe")
    func test_plainStringScalarPolicy() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("Example title")),
            .init(key: "truth", value: .string("true")),
            .init(key: "number", value: .string("42")),
            .init(key: "colon", value: .string("a: b")),
            .init(key: "hash", value: .string("a#b")),
            .init(key: "dash", value: .string("- item")),
            .init(key: "trim", value: .string(" padded")),
            .init(key: "newline", value: .string("line\nnext")),
        ]))
        let options = PureYAML.Emitting.Options(scalarStyle: .plainWhenSafe)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        title: Example title
        truth: "true"
        number: "42"
        colon: "a: b"
        hash: "a#b"
        dash: "- item"
        trim: " padded"
        newline: "line\\nnext"

        """)
        #expect(!yaml.contains("title: \"Example title\""))
        #expect(yaml.contains("truth: \"true\""))
        #expect(try PureYAML.parse(yaml) == value)
    }

    @Test("Dumper accepts explicit default options")
    func test_explicitDefaultOptions() {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("Example")),
        ]))
        let dumper = PureYAML.Emitting.Dumper(options: .default)

        #expect(dumper.dump(value) == PureYAML.dump(value))
    }
}
