@testable import PureYAML
import Testing

@Suite("Complex Mapping Key Parsing")
struct ComplexMappingKeyParsingTests {
    @Test("Parses block sequence keys as first-class key nodes")
    func test_parsesBlockSequenceKeysAsFirstClassKeyNodes() throws {
        let value = try PureYAML.parse("""
        ? [Detroit Tigers, Chicago Cubs]
        :
          - 2001-07-23
        """)
        let expectedKey = PureYAML.Model.Key.sequence([
            .string("Detroit Tigers"),
            .string("Chicago Cubs"),
        ])

        #expect(value == .mapping(.init([
            .init(
                keyNode: expectedKey,
                value: .sequence([.string("2001-07-23")]),
            ),
        ])))
        #expect(value.rootMapping?.pairs.first?.keyNode == expectedKey)
        #expect(value.rootMapping?.pairs.first?.key == "[\"Detroit Tigers\", \"Chicago Cubs\"]")
        #expect(value.rootMapping?["Detroit Tigers"] == nil)
        #expect(value.rootMapping?[expectedKey] == .sequence([.string("2001-07-23")]))
    }

    @Test("Parses block mapping keys as first-class key nodes")
    func test_parsesBlockMappingKeysAsFirstClassKeyNodes() throws {
        let value = try PureYAML.parse("""
        ? {name: Example, version: 1}
        : active
        """)
        let expectedKey = PureYAML.Model.Key.mapping(.init([
            .init(key: "name", value: .string("Example")),
            .init(key: "version", value: .int(1)),
        ]))

        #expect(value == .mapping(.init([
            .init(keyNode: expectedKey, value: .string("active")),
        ])))
        #expect(value.rootMapping?.pairs.first?.keyNode.description == """
        {"name": "Example", "version": 1}
        """)
        #expect(value.rootMapping?["name"] == nil)
        #expect(value.rootMapping?[expectedKey] == .string("active"))
    }

    @Test("Keeps scalar mapping keys string-keyed even when tags look typed")
    func test_keepsScalarMappingKeysStringKeyedEvenWhenTagsLookTyped() throws {
        let value = try PureYAML.parse("""
        ? !!int 1
        : integer-looking
        ? true
        : boolean-looking
        """)

        #expect(value == .mapping(.init([
            .init(key: "1", value: .string("integer-looking")),
            .init(key: "true", value: .string("boolean-looking")),
        ])))
        #expect(value.rootMapping?["1"] == .string("integer-looking"))
        #expect(value.rootMapping?["true"] == .string("boolean-looking"))
        #expect(value.rootMapping?[.sequence([.string("1")])] == nil)
    }

    @Test("Parses alias-backed complex keys without string coercion")
    func test_parsesAliasBackedComplexKeysWithoutStringCoercion() throws {
        let value = try PureYAML.parse("""
        pair: &pair [a, b]
        ? *pair
        : value
        """)
        let key = PureYAML.Model.Key.sequence([.string("a"), .string("b")])

        #expect(value == .mapping(.init([
            .init(key: "pair", value: .sequence([.string("a"), .string("b")])),
            .init(keyNode: key, value: .string("value")),
        ])))
        #expect(value.rootMapping?["pair"] == .sequence([.string("a"), .string("b")]))
        #expect(value.rootMapping?[key] == .string("value"))
        #expect(value.rootMapping?["[\"a\", \"b\"]"] == nil)
    }

    @Test("Parses explicit scalar keys with same-line mapping values")
    func test_parsesExplicitScalarKeysWithSameLineMappingValues() throws {
        let value = try PureYAML.parse("""
        ? __stringMin14PatternS3Captions
        : minLength: 14
          pattern: ^((s3://(.*?)\\.(srt|SRT))|(https?://(.*?)\\.(srt|SRT)))$
          type: string
        next: done
        """)
        let key = PureYAML.Model.Key.string("__stringMin14PatternS3Captions")

        #expect(value == .mapping(.init([
            .init(keyNode: key, value: .mapping(.init([
                .init(key: "minLength", value: .int(14)),
                .init(
                    key: "pattern",
                    value: .string("^((s3://(.*?)\\.(srt|SRT))|(https?://(.*?)\\.(srt|SRT)))$"),
                ),
                .init(key: "type", value: .string("string")),
            ]))),
            .init(key: "next", value: .string("done")),
        ])))
        #expect(value.rootMapping?[key]?.rootMapping?["minLength"] == .int(14))
        #expect(value.rootMapping?[key]?.rootMapping?["type"] == .string("string"))
        #expect(value.rootMapping?["next"] == .string("done"))
        #expect(value.rootMapping?["minLength"] == nil)
    }

    @Test("Expands merged mappings with complex-key local overrides")
    func test_expandsMergedMappingsWithComplexKeyLocalOverrides() throws {
        let value = try PureYAML.parse("""
        defaults: &defaults
          ? [a, b]
          : inherited
          name: inherited-name
        service:
          <<: *defaults
          ? [a, b]
          : local
        """)
        let service = value.rootMapping?["service"]
        let key = PureYAML.Model.Key.sequence([.string("a"), .string("b")])

        #expect(service == .mapping(.init([
            .init(key: "name", value: .string("inherited-name")),
            .init(keyNode: key, value: .string("local")),
        ])))
        #expect(try PureYAML.validate(value, strict: false).isEmpty)
        #expect(service?.rootMapping?[key] == .string("local"))
        #expect(service?.rootMapping?["[\"a\", \"b\"]"] == nil)
    }

    @Test("Rejects complex keys that are not followed by mapping values")
    func test_rejectsComplexKeysThatAreNotFollowedByMappingValues() {
        expectParseError("""
        ? [a, b]
        - invalid
        """, .unexpectedToken(
            expected: "mapping value",
            actual: "blockEntry",
            line: 2,
            column: 1,
        ))
    }
}
