@testable import PureYAML
import Testing

@Suite("Event Streaming Parser")
struct EventStreamingParserTests {
    @Test(
        "Streaming composer matches full event composer for single documents",
        arguments: EventStreamingFixtures.singleDocuments,
    )
    func test_streamingComposerMatchesFullEventComposer(testCase: EventStreamingFixtures.DocumentCase) throws {
        let parser = PureYAML.Parsing.Parser()
        let streaming = try parser.parse(testCase.yaml)
        let fullEvents = try composeSingleDocumentWithFullEvents(testCase.yaml)

        #expect(streaming == fullEvents)
    }

    @Test(
        "Streaming composer matches full event composer for streams",
        arguments: EventStreamingFixtures.streams,
    )
    func test_streamingComposerMatchesFullEventComposerForStreams(testCase: EventStreamingFixtures.DocumentCase) throws {
        let parser = PureYAML.Parsing.Parser()
        let streaming = try parser.parseStream(testCase.yaml)
        let fullEvents = try composeStreamWithFullEvents(testCase.yaml)

        #expect(streaming == fullEvents)
    }

    @Test("Streaming parser preserves duplicate keys for validation")
    func test_streamingParserPreservesDuplicateKeysForValidation() throws {
        let value = try PureYAML.parse("""
        root:
          title: First
          title: Second
        flow: {id: one, id: two}
        """)

        let issues = PureYAML.Validation.Validator().collect(value).issues

        #expect(issues.map(\.description) == [
            "error: Duplicate mapping key 'title' at $.root.title",
            "error: Duplicate mapping key 'id' at $.flow.id",
        ])
    }

    @Test(
        "Lazy token cursor matches full scanner tokens",
        arguments: EventStreamingFixtures.singleDocuments + EventStreamingFixtures.streams,
    )
    func test_lazyTokenCursorMatchesFullScannerTokens(testCase: EventStreamingFixtures.DocumentCase) throws {
        let full = try PureYAML.Parsing.Scanner().scan(testCase.yaml)
            .filter { !$0.kind.isComment }
        let lazy = try collectLazyTokens(testCase.yaml)

        #expect(lazy == full)
    }
}

enum EventStreamingFixtures {
    struct DocumentCase: CustomTestStringConvertible {
        var name: String
        var yaml: String

        var testDescription: String {
            name
        }
    }

    static let singleDocuments = [
        DocumentCase(
            name: "block mappings and sequences",
            yaml: """
            servers:
              - url: /
                description: Default
            """,
        ),
        DocumentCase(
            name: "anchors aliases and merge keys",
            yaml: """
            defaults: &defaults
              enabled: true
              retries: 3
            service:
              <<: *defaults
              name: API
            """,
        ),
        DocumentCase(
            name: "flow collections and tags",
            yaml: """
            flow: [!Thing &item "value", *item, {tagged: !<tag:example.com,2026:thing> 'it''s'}]
            """,
        ),
        DocumentCase(
            name: "block scalars",
            yaml: """
            text: |
              one
              two
            folded: >
              three
              four
            """,
        ),
        DocumentCase(
            name: "JSON style input",
            yaml: #"{"openapi":"3.0.0","info":{"title":"JSON API"},"items":["a:b","c"],"enabled":true}"#,
        ),
        DocumentCase(
            name: "complex mapping key",
            yaml: """
            ? {name: service, version: 1}
            : active
            """,
        ),
    ]

    static let streams = [
        DocumentCase(
            name: "multi document sequence stream",
            yaml: """
            ---
            - one
            - two
            ---
            name: three
            ...
            ---
            null
            """,
        ),
        DocumentCase(
            name: "empty explicit documents",
            yaml: """
            ---
            ...
            ---
            """,
        ),
    ]
}

private func composeSingleDocumentWithFullEvents(_ yaml: String) throws -> PureYAML.Model.Value {
    let parser = PureYAML.Parsing.Parser()
    let events = try parser.parseEvents(yaml)
    var composer = PureYAML.Parsing.EventComposer(events: events, scalarParser: parser)
    return try composer.compose()
}

private func composeStreamWithFullEvents(_ yaml: String) throws -> [PureYAML.Stream.Document] {
    let parser = PureYAML.Parsing.Parser()
    let events = try parser.parseEvents(yaml)
    var composer = PureYAML.Parsing.EventComposer(events: events, scalarParser: parser)
    return try composer.composeStream()
}

private func collectLazyTokens(_ yaml: String) throws -> [PureYAML.Parsing.Token] {
    var cursor = PureYAML.Parsing.TokenCursor(yaml: yaml)
    var tokens: [PureYAML.Parsing.Token] = []
    while let token = cursor.current {
        tokens.append(token)
        _ = try cursor.advance()
    }
    return tokens
}
