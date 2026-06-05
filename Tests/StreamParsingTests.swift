@testable import PureYAML
import Testing

@Suite("Stream Parsing")
struct StreamParsingTests {
    @Test("Parses one implicit document as an indexed stream")
    func test_parseStreamReturnsOneImplicitDocument() throws {
        let documents = try PureYAML.parseStream(
            """
            title: Example
            active: true
            """,
        )

        #expect(documents == [
            .init(index: 0, value: .mapping(.init([
                .init(key: "title", value: .string("Example")),
                .init(key: "active", value: .bool(true)),
            ]))),
        ])
        #expect(documents.map(\.index) == [0])
        #expect(!documents.contains(.init(index: 0, value: .string("---"))))
    }

    @Test("Parses empty explicit documents as null values")
    func test_emptyExplicitDocumentsBecomeNullValues() throws {
        let documents = try PureYAML.parseStream(
            """
            # A document may be null.
            ---
            ---
            empty:
            canonical: ~
            ---
            sparse:
              - ~
              -
              - value
            """,
        )

        #expect(documents == [
            .init(index: 0, value: .null),
            .init(index: 1, value: .mapping(.init([
                .init(key: "empty", value: .null),
                .init(key: "canonical", value: .null),
            ]))),
            .init(index: 2, value: .mapping(.init([
                .init(key: "sparse", value: .sequence([
                    .null,
                    .null,
                    .string("value"),
                ])),
            ]))),
        ])
        #expect(documents.count == 3)
        #expect(documents[0].value != .string(""))
    }

    @Test("Parses multiple sequence documents")
    func test_multipleSequenceDocuments() throws {
        let documents = try PureYAML.parseStream(
            """
            # Ranking of 1998 home runs
            ---
            - Mark McGwire
            - Sammy Sosa
            - Ken Griffey

            # Team ranking
            ---
            - Chicago Cubs
            - St Louis Cardinals
            """,
        )

        #expect(documents == [
            .init(index: 0, value: .sequence([
                .string("Mark McGwire"),
                .string("Sammy Sosa"),
                .string("Ken Griffey"),
            ])),
            .init(index: 1, value: .sequence([
                .string("Chicago Cubs"),
                .string("St Louis Cardinals"),
            ])),
        ])
        #expect(documents.map(\.index) == [0, 1])
        #expect(!documents.map(\.value).contains(.string("# Team ranking")))
    }

    @Test("Parses document end markers trailing comments and following starts")
    func test_documentEndMarkersTrailingCommentsAndFollowingStarts() throws {
        let documents = try PureYAML.parseStream(
            """
            ---
            time: "20:03:20"
            player: Sammy Sosa
            action: strike (miss)
            ...
            # separator comment
            ---
            time: "20:03:47"
            player: Sammy Sosa
            action: grand slam
            ...
            """,
        )

        #expect(documents == [
            .init(index: 0, value: .mapping(.init([
                .init(key: "time", value: .string("20:03:20")),
                .init(key: "player", value: .string("Sammy Sosa")),
                .init(key: "action", value: .string("strike (miss)")),
            ]))),
            .init(index: 1, value: .mapping(.init([
                .init(key: "time", value: .string("20:03:47")),
                .init(key: "player", value: .string("Sammy Sosa")),
                .init(key: "action", value: .string("grand slam")),
            ]))),
        ])
        #expect(!documents.map(\.value).contains(.string("separator comment")))
    }

    @Test("Single document parser accepts one explicit empty document")
    func test_singleDocumentParserAcceptsOneExplicitEmptyDocument() throws {
        #expect(try PureYAML.parse("---") == .null)
        #expect(try PureYAML.parse("---\n...\n# trailing comment") == .null)
    }

    @Test("Single document parser rejects multiple documents exactly")
    func test_singleDocumentParserRejectsMultipleDocuments() {
        expectParseError(
            """
            document 1
            ---
            document 2
            """,
            .unsupportedMultiDocumentStream(line: 2),
        )
    }

    @Test("Stream parser rejects content after explicit document end without next start")
    func test_streamParserRejectsContentAfterExplicitDocumentEndWithoutNextStart() {
        expectStreamParseError(
            """
            name: First
            ...
            name: Second
            """,
            .unsupportedMultiDocumentStream(line: 3),
            description: "multi-document streams are not supported at line 3",
        )
    }

    @Test("Stream parser rejects extra root content without a document start")
    func test_streamParserRejectsExtraRootContentWithoutDocumentStart() {
        expectStreamParseError(
            """
            first
            second
            """,
            .unexpectedToken(
                expected: "document boundary or stream end",
                actual: "scalar value=\"second\" style=plain",
                line: 2,
                column: 1,
            ),
            description: "expected document boundary or stream end at line 2, column 1, found scalar value=\"second\" style=plain",
        )
    }

    @Test("Stream parser rejects aliases that cross document boundaries")
    func test_streamParserRejectsCrossDocumentAliases() {
        expectStreamParseError(
            """
            ---
            value: &shared first
            ---
            copy: *shared
            """,
            .undefinedAlias(anchor: "shared", line: 4, column: 7),
            description: "undefined alias 'shared' at line 4, column 7",
        )
    }
}

@Suite("Stream Validation")
struct StreamValidationTests {
    @Test("Validates stream documents with exact document-indexed diagnostics")
    func test_streamValidationPreservesDocumentIndexes() throws {
        let documents = try PureYAML.parseStream(
            """
            ---
            title: First
            title: Second
            ---
            routes:
              - name: Users
                name: People
            """,
        )
        let expectedIssues = [
            PureYAML.Stream.Issue(
                documentIndex: 0,
                issue: .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("title")]),
                ),
            ),
            PureYAML.Stream.Issue(
                documentIndex: 1,
                issue: .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'name'",
                    path: .init([.key("routes"), .index(0), .key("name")]),
                ),
            ),
        ]

        let result = PureYAML.Validation.Validator().collect(documents)
        #expect(result.issues == expectedIssues)
        #expect(result.errors == expectedIssues)
        #expect(result.warnings.isEmpty)
        #expect(!result.isValid)
        expectStreamValidationError(documents) { collection in
            #expect(collection.issues == expectedIssues)
            #expect(collection.description == """
            document[0]: error: Duplicate mapping key 'title' at $.title
            document[1]: error: Duplicate mapping key 'name' at $.routes[0].name
            """)
        }
    }

    @Test("Valid stream documents produce no diagnostics")
    func test_validStreamDocumentsProduceNoDiagnostics() throws {
        let documents = try PureYAML.parseStream(
            """
            ---
            title: First
            ---
            - one
            - two
            """,
        )

        let result = PureYAML.Validation.Validator().collect(documents)
        #expect(result == PureYAML.Stream.Result())
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
        #expect(try PureYAML.validate(documents).isEmpty)
    }

    @Test("Stream validation preserves strict and non-strict warning behavior")
    func test_streamValidationStrictAndNonStrictWarnings() throws {
        let documents = [
            PureYAML.Stream.Document(index: 4, value: .string("legacy")),
            PureYAML.Stream.Document(index: 5, value: .string("modern")),
        ]
        let validator = PureYAML.Validation.Validator.blank
            .validating(legacyModeRule(severity: .warning))
        let expectedIssues = [
            PureYAML.Stream.Issue(
                documentIndex: 4,
                issue: .init(
                    severity: .warning,
                    reason: "Legacy mode is not allowed",
                    path: .root,
                ),
            ),
        ]

        expectStreamValidationError(documents, using: validator) { collection in
            #expect(collection.issues == expectedIssues)
        }
        let warnings = try PureYAML.validate(documents, using: validator, strict: false)
        #expect(warnings == expectedIssues)

        let modernOnly = [PureYAML.Stream.Document(index: 6, value: .string("modern"))]
        #expect(PureYAML.Validation.Validator.blank
            .validating(legacyModeRule(severity: .warning))
            .collect(modernOnly)
            .issues
            .isEmpty)
    }
}

private func expectStreamParseError(
    _ yaml: String,
    _ expected: PureYAML.Parsing.ParseError,
    description: String,
) {
    do {
        _ = try PureYAML.parseStream(yaml)
        recordIssue("expected error \(expected)")
    } catch let error as PureYAML.Parsing.ParseError {
        #expect(error == expected)
        #expect(error.description == description)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}

private func expectStreamValidationError(
    _ documents: [PureYAML.Stream.Document],
    using validator: PureYAML.Validation.Validator = .init(),
    check: (PureYAML.Stream.Issue.Collection) -> Void,
) {
    do {
        try PureYAML.validate(documents, using: validator)
        recordIssue("expected stream validation failure")
    } catch let collection as PureYAML.Stream.Issue.Collection {
        check(collection)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}
