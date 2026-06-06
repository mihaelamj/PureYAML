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
            .init(key: "description ", value: .string("keeps trailing key space")),
        ]))

        #expect(PureYAML.dump(value) == """
        a:b: "quote \\" slash \\\\ tab\\t"
        "hash#key": "line\\nnext"
        "description ": "keeps trailing key space"

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

    @Test("Dumps selected top-level multiline strings as literal block scalars")
    func test_literalBlockScalarPolicyTopLevelString() throws {
        let value = PureYAML.Model.Value.string("one\ntwo\n")
        let options = PureYAML.Emitting.Options(scalarStyle: .literalBlockWhenMultiline)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        |
          one
          two

        """)
        #expect(!yaml.contains("\\n"))
        #expect(try PureYAML.parse(yaml) == value)
    }

    @Test("Dumps selected mapping values and sequence items as literal block scalars")
    func test_literalBlockScalarPolicyCollections() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("Example")),
            .init(key: "body", value: .string("one\ntwo\n")),
            .init(key: "items", value: .sequence([
                .string("alpha\nbeta"),
                .string("gamma"),
            ])),
        ]))
        let options = PureYAML.Emitting.Options(scalarStyle: .literalBlockWhenMultiline)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        title: "Example"
        body: |
          one
          two
        items:
          - |-
            alpha
            beta
          - "gamma"

        """)
        #expect(!yaml.contains("one\\ntwo"))
        #expect(!yaml.contains("alpha\\nbeta"))
        #expect(try PureYAML.parse(yaml) == value)
    }

    @Test("Dumps unsafe multiline strings as quoted scalars")
    func test_literalBlockScalarPolicyKeepsUnsafeMultilineStringsQuoted() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "colon", value: .string("one: two\nnext")),
            .init(key: "hash", value: .string("one # two\nnext")),
            .init(key: "leading", value: .string("one\n next")),
        ]))
        let options = PureYAML.Emitting.Options(scalarStyle: .literalBlockWhenMultiline)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        colon: "one: two\\nnext"
        hash: "one # two\\nnext"
        leading: "one\\n next"

        """)
        #expect(try PureYAML.parse(yaml) == value)
    }

    @Test("Dumps selected sequences as flow collections")
    func test_flowCollectionPolicySequence() throws {
        let value = PureYAML.Model.Value.sequence([
            .string("one"),
            .int(2),
            .bool(false),
        ])
        let options = PureYAML.Emitting.Options(collectionStyle: .flow)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == "[\"one\", 2, false]\n")
        #expect(!yaml.contains("\n- "))
        #expect(try PureYAML.parse(yaml) == value)
    }

    @Test("Dumps selected mappings as flow collections")
    func test_flowCollectionPolicyMapping() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "name", value: .string("Example")),
            .init(key: "tags", value: .sequence([
                .string("Swift"),
                .string("YAML"),
            ])),
            .init(key: "meta", value: .mapping(.init([
                .init(key: "enabled", value: .bool(true)),
            ]))),
        ]))
        let options = PureYAML.Emitting.Options(collectionStyle: .flow)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        {"name": "Example", "tags": ["Swift", "YAML"], "meta": {"enabled": true}}

        """)
        #expect(!yaml.contains("\n  "))
        #expect(try PureYAML.parse(yaml) == value)
    }

    @Test("Dumps flow scalars with escaping")
    func test_flowCollectionPolicyEscapesScalars() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "a:b", value: .string("quote \" slash \\ comma, bracket [x]")),
            .init(key: "lines", value: .string("one\ntwo")),
        ]))
        let options = PureYAML.Emitting.Options(collectionStyle: .flow)
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        {"a:b": "quote \\" slash \\\\ comma, bracket [x]", "lines": "one\\ntwo"}

        """)
        #expect(try PureYAML.parse(yaml) == value)
    }

    @Test("Dumps flow plain strings only when selected and safe")
    func test_flowCollectionPolicyPlainScalarPolicy() throws {
        let value = PureYAML.Model.Value.sequence([
            .string("Example title"),
            .string("a, b"),
            .string("true"),
            .string("bracket [x]"),
        ])
        let options = PureYAML.Emitting.Options(
            scalarStyle: .plainWhenSafe,
            collectionStyle: .flow,
        )
        let yaml = PureYAML.dump(value, options: options)

        #expect(yaml == """
        [Example title, "a, b", "true", "bracket [x]"]

        """)
        #expect(!yaml.contains("\"Example title\""))
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
