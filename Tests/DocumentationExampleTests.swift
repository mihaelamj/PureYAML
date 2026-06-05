@testable import PureYAML
import Testing

@Suite("Documentation Examples")
struct DocumentationExampleTests {
    struct Info: Codable, Equatable {
        var title: String
        var version: Int
    }

    @Test("README parse dump and validate example stays executable")
    func test_readmeParseDumpAndValidateExample() throws {
        let document = try PureYAML.parse(
            """
            openapi: 3.1.0
            info:
              title: Example API
            servers:
              - url: /
            """,
        )

        let root = requireMapping(document, "expected README document mapping")
        let info = expectMapping(root?["info"], "expected README info mapping")
        let servers = requireSequence(root?["servers"], "expected README servers sequence")
        let server = expectMapping(servers?.first, "expected README server mapping")
        let yaml = PureYAML.dump(document)

        #expect(root?.pairs.map(\.key) == ["openapi", "info", "servers"])
        #expect(root?["openapi"] == .string("3.1.0"))
        #expect(root?["swagger"] == nil)
        #expect(info?["title"] == .string("Example API"))
        #expect(server?["url"] == .string("/"))
        #expect(try PureYAML.validate(document).isEmpty)
        #expect(yaml == """
        openapi: "3.1.0"
        info:
          title: "Example API"
        servers:
          -
            url: "/"

        """)
        #expect(try PureYAML.parse(yaml) == document)
    }

    @Test("README typed conversion example stays executable")
    func test_readmeTypedConversionExample() throws {
        let info = try PureYAML.decode(Info.self, from: """
        title: Example API
        version: 1
        """)
        let tags = try PureYAML.decode([String].self, from: """
        - Swift
        - YAML
        """)
        let value = try PureYAML.encode(42)
        let yaml = try PureYAML.encodeToYAML(info)

        #expect(try PureYAML.decode(String.self, from: "Example") == "Example")
        #expect(info == Info(title: "Example API", version: 1))
        #expect(tags == ["Swift", "YAML"])
        #expect(value == .int(42))
        #expect(yaml == """
        title: "Example API"
        version: 1

        """)
        #expect(try PureYAML.decode(Info.self, from: yaml) == info)
    }

    @Test("README stream parsing example stays executable")
    func test_readmeStreamParsingExample() throws {
        let documents = try PureYAML.parseStream(
            """
            ---
            title: First
            ---
            - Swift
            - YAML
            """,
        )

        #expect(documents == [
            .init(index: 0, value: .mapping(.init([
                .init(key: "title", value: .string("First")),
            ]))),
            .init(index: 1, value: .sequence([
                .string("Swift"),
                .string("YAML"),
            ])),
        ])
        #expect(try PureYAML.validate(documents).isEmpty)
        #expect(PureYAML.dump(documents) == """
        ---
        title: "First"
        ---
        - "Swift"
        - "YAML"

        """)
    }

    @Test("README tagged parsing example stays executable")
    func test_readmeTaggedParsingExample() throws {
        let tagged = try PureYAML.parseTagged(
            """
            value: !!timestamp 2001-01-23
            """,
        )
        let tagIssues = PureYAML.Tagged.Validator().collect(tagged)
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:timestamp'",
                path: .init([.key("value")]),
            ),
        ]

        #expect(tagIssues.issues == expectedIssues)
    }

    @Test("README tagged constructor example stays executable")
    func test_readmeTaggedConstructorExample() throws {
        let tagged = try PureYAML.parseTagged("!Env DATABASE_URL")
        let constructor = PureYAML.Tagged.Constructor<String>()
            .constructingScalar(tag: .init("!Env")) { scalar, _ in
                scalar.rawValue
            }
        let env = try constructor.construct(tagged)

        #expect(env == "DATABASE_URL")
    }

    @Test("README emitter options example stays executable")
    func test_readmeEmitterOptionsExample() throws {
        let document = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("Example API")),
            .init(key: "body", value: .string("one\ntwo\n")),
            .init(key: "tags", value: .sequence([
                .string("Swift"),
                .string("YAML"),
            ])),
        ]))

        let readable = PureYAML.Emitting.Options(
            scalarStyle: .literalBlockWhenMultiline,
        )
        let compact = PureYAML.Emitting.Options(collectionStyle: .flow)
        let readableYAML = PureYAML.dump(document, options: readable)
        let compactYAML = PureYAML.dump(document, options: compact)

        #expect(readableYAML == """
        title: "Example API"
        body: |
          one
          two
        tags:
          - "Swift"
          - "YAML"

        """)
        #expect(!readableYAML.contains("one\\ntwo"))
        #expect(try PureYAML.parse(readableYAML) == document)
        #expect(compactYAML == """
        {"title": "Example API", "body": "one\\ntwo\\n", "tags": ["Swift", "YAML"]}

        """)
        #expect(!compactYAML.contains("\n  - "))
        #expect(try PureYAML.parse(compactYAML) == document)
    }

    @Test("README validation example stays executable")
    func test_readmeValidationExample() throws {
        let validDocument = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("Example API")),
        ]))
        let document = PureYAML.Model.Value.mapping(.init([
            .init(key: "title", value: .string("First")),
            .init(key: "title", value: .string("Second")),
        ]))
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("title")]),
            ),
        ]
        let result = PureYAML.Validation.Validator().collect(document)

        #expect(try PureYAML.validate(validDocument, strict: false).isEmpty)
        #expect(result.errors == expectedIssues)
        #expect(result.warnings.isEmpty)
        expectValidationFailure(document) { collection in
            #expect(collection.issues == expectedIssues)
            #expect(collection.description == "error: Duplicate mapping key 'title' at $.title")
        }
    }

    func expectMapping(
        _ value: PureYAML.Model.Value?,
        _ message: String,
    ) -> PureYAML.Model.Mapping? {
        guard case let .mapping(mapping)? = value else {
            recordIssue(message)
            return nil
        }
        return mapping
    }

    func expectValidationFailure(
        _ value: PureYAML.Model.Value,
        check: (PureYAML.Validation.Issue.Collection) -> Void,
    ) {
        do {
            _ = try PureYAML.validate(value)
            recordIssue("expected validation failure")
        } catch let collection as PureYAML.Validation.Issue.Collection {
            check(collection)
        } catch {
            recordIssue("unexpected error \(error)")
        }
    }
}
