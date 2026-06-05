@testable import PureYAML
import Testing

@Suite("Tagged Compatibility")
struct TaggedCompatibilityTests {
    @Test("Parses explicit scalar and collection tags into a tagged node tree")
    func test_parsesExplicitScalarAndCollectionTags() throws {
        let root = try requireTaggedMapping(PureYAML.parseTagged(
            """
            root: !<tag:example.com,2026:root> {items: !!seq [!!str true, !Thing false], meta: !!map {enabled: !!bool "false"}}
            """,
        ))
        let taggedRoot = try requireTaggedMapping(root?["root"], "expected custom-tagged root mapping")
        let items = try requireTaggedSequence(taggedRoot?["items"], "expected tagged items sequence")
        let meta = try requireTaggedMapping(taggedRoot?["meta"], "expected tagged meta mapping")
        let enabled = try requireTaggedScalar(meta?["enabled"], "expected tagged enabled scalar")
        let firstItem = try requireTaggedScalar(items?.values.first, "expected first tagged item")
        let secondItem = try requireTaggedScalar(items?.values.dropFirst().first, "expected second tagged item")

        #expect(taggedRoot?.tag == .init("tag:example.com,2026:root"))
        #expect(items?.tag == .sequence)
        #expect(meta?.tag == .mapping)
        #expect(enabled?.tag == .bool)
        #expect(enabled?.value == .bool(false))
        #expect(firstItem?.tag == .string)
        #expect(firstItem?.value == .string("true"))
        #expect(secondItem?.tag == .init("!Thing"))
        #expect(secondItem?.value == .bool(false))
        #expect(PureYAML.Tagged.Validator().collect(.mapping(root ?? .init(pairs: []))) == .init())
    }

    @Test("Model parsing keeps unsupported Foundation-backed tags as plain value trees")
    func test_modelParsingKeepsFoundationBackedTagsAsPlainValues() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            date: !!timestamp 2001-01-23
            payload: !!binary |
              YWJj
            """,
        ))

        #expect(root?["date"] == .string("2001-01-23"))
        #expect(root?["payload"] == .string("YWJj\n"))
    }
}

@Suite("Tagged Validation Compatibility")
struct TaggedValidationCompatibilityTests {
    @Test("Validates unsupported built-in tags exactly")
    func test_validatesUnsupportedBuiltInTagsExactly() throws {
        let node = try PureYAML.parseTagged(
            """
            date: !!timestamp 2001-01-23
            payload: !!binary |
              YWJj
            set: !!set {a: null}
            omap: !!omap [{a: 1}, {b: 2}]
            pairs: !!pairs [{a: 1}]
            """,
        )
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:timestamp'",
                path: .init([.key("date")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:binary'",
                path: .init([.key("payload")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:set'",
                path: .init([.key("set")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:omap'",
                path: .init([.key("omap")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:pairs'",
                path: .init([.key("pairs")]),
            ),
        ]
        let result = PureYAML.Tagged.Validator().collect(node)

        #expect(result.issues == expectedIssues)
        #expect(result.errors == expectedIssues)
        expectTaggedValidationError(node) { collection in
            #expect(collection.issues == expectedIssues)
            #expect(collection.description == expectedIssues.map(\.description).joined(separator: "\n"))
        }
    }

    @Test("Validates built-in tags applied to the wrong node kind exactly")
    func test_validatesWrongKindBuiltInTagsExactly() throws {
        let node = try PureYAML.parseTagged(
            """
            seq: !!seq {a: 1}
            map: !!map [a]
            scalar: !!str [a]
            """,
        )
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Tag 'tag:yaml.org,2002:seq' expects a sequence node, found mapping",
                path: .init([.key("seq")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Tag 'tag:yaml.org,2002:map' expects a mapping node, found sequence",
                path: .init([.key("map")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Tag 'tag:yaml.org,2002:str' expects a scalar node, found sequence",
                path: .init([.key("scalar")]),
            ),
        ]

        #expect(PureYAML.Tagged.Validator().collect(node).issues == expectedIssues)
    }

    @Test("Validates unsupported and inconsistent mapping key tags exactly")
    func test_validatesMappingKeyTagsExactly() throws {
        let node = try PureYAML.parseTagged(
            """
            ? !!timestamp 2001-01-23
            : value
            ? !!seq key
            : value
            ? !!merge not-merge
            : value
            ? !!merge <<
            : value
            """,
        )
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:timestamp' on mapping key",
                path: .init([.key("2001-01-23")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Tag 'tag:yaml.org,2002:seq' expects a scalar mapping key",
                path: .init([.key("key")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Tag 'tag:yaml.org,2002:merge' is only supported on '<<' mapping keys",
                path: .init([.key("not-merge")]),
            ),
        ]
        let mapping = try requireTaggedMapping(node)

        #expect(mapping?.pairs.map(\.key) == ["2001-01-23", "key", "not-merge", "<<"])
        #expect(PureYAML.Tagged.Validator().collect(node).issues == expectedIssues)
    }

    @Test("Validates mapping node tags and mapping key tags in one deterministic pass")
    func test_validatesMappingNodeAndKeyTagsTogether() {
        let node = PureYAML.Tagged.Node.mapping(.init(
            pairs: [
                .init(
                    key: "2001-01-23",
                    keyTag: .timestamp,
                    value: .scalar(.init(rawValue: "value", value: .string("value"))),
                ),
            ],
            tag: .set,
        ))
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:timestamp' on mapping key",
                path: .init([.key("2001-01-23")]),
            ),
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:set'",
                path: .root,
            ),
        ]

        #expect(PureYAML.Tagged.Validator().collect(node).issues == expectedIssues)
    }

    @Test("Allows project-specific tags for application validation")
    func test_allowsProjectSpecificTagsForApplicationValidation() throws {
        let node = try PureYAML.parseTagged(
            """
            thing: !<tag:example.com,2026:thing> {name: Example}
            local: !Local [one, two]
            """,
        )
        let root = try requireTaggedMapping(node)
        let thing = try requireTaggedMapping(root?["thing"], "expected custom thing mapping")
        let local = try requireTaggedSequence(root?["local"], "expected local tagged sequence")

        #expect(thing?.tag == .init("tag:example.com,2026:thing"))
        #expect(local?.tag == .init("!Local"))
        #expect(PureYAML.Tagged.Validator().collect(node) == .init())
    }

    @Test("Custom tagged validation rules inspect application tags exactly")
    func test_customTaggedValidationRulesInspectApplicationTagsExactly() throws {
        let node = try PureYAML.parseTagged("value: !Local one")
        let localTagsAreWarnings = PureYAML.Tagged.Rule(description: "Local tags are warnings") { context in
            guard context.subject.tag == .init("!Local") else {
                return []
            }
            return [
                PureYAML.Validation.Issue(
                    severity: .warning,
                    reason: "Local application tag requires caller handling",
                    path: context.path,
                ),
            ]
        }
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .warning,
                reason: "Local application tag requires caller handling",
                path: .init([.key("value")]),
            ),
        ]
        let validator = PureYAML.Tagged.Validator.blank.validating(localTagsAreWarnings)

        #expect(PureYAML.Tagged.Validator.blank.collect(node) == .init())
        #expect(validator.collect(node).issues == expectedIssues)
        #expect(try validator.validate(node, strict: false) == expectedIssues)
        expectTaggedValidationError(node, using: validator) { collection in
            #expect(collection.issues == expectedIssues)
        }
    }

    @Test("Validates tagged streams with document-indexed diagnostics")
    func test_validatesTaggedStreamsWithDocumentIndexedDiagnostics() throws {
        let documents = try PureYAML.parseTaggedStream(
            """
            ---
            value: !!str true
            ---
            value: !!timestamp 2001-01-23
            """,
        )
        let expectedIssues = [
            PureYAML.Stream.Issue(
                documentIndex: 1,
                issue: .init(
                    severity: .error,
                    reason: "Unsupported built-in tag 'tag:yaml.org,2002:timestamp'",
                    path: .init([.key("value")]),
                ),
            ),
        ]

        #expect(documents.map(\.index) == [0, 1])
        #expect(PureYAML.Tagged.Validator().collect(documents).issues == expectedIssues)
    }

    @Test("Tagged parsing reports invalid explicit scalar tags exactly")
    func test_taggedParsingReportsInvalidExplicitScalarTagsExactly() {
        expectError(
            PureYAML.Parsing.ParseError.invalidTaggedScalar(
                tag: "tag:yaml.org,2002:int",
                value: "nope",
                line: 1,
                column: 8,
            ),
        ) {
            _ = try PureYAML.parseTagged("value: !!int nope")
        }
    }
}

private func requireTaggedMapping(
    _ node: PureYAML.Tagged.Node?,
    _ message: String = "expected tagged mapping",
) throws -> PureYAML.Tagged.Mapping? {
    guard case let .mapping(mapping)? = node else {
        recordIssue(message)
        return nil
    }
    return mapping
}

private func requireTaggedSequence(
    _ node: PureYAML.Tagged.Node?,
    _ message: String = "expected tagged sequence",
) throws -> PureYAML.Tagged.Sequence? {
    guard case let .sequence(sequence)? = node else {
        recordIssue(message)
        return nil
    }
    return sequence
}

private func requireTaggedScalar(
    _ node: PureYAML.Tagged.Node?,
    _ message: String = "expected tagged scalar",
) throws -> PureYAML.Tagged.Scalar? {
    guard case let .scalar(scalar)? = node else {
        recordIssue(message)
        return nil
    }
    return scalar
}

private func expectTaggedValidationError(
    _ node: PureYAML.Tagged.Node,
    using validator: PureYAML.Tagged.Validator = .init(),
    body: (PureYAML.Validation.Issue.Collection) -> Void,
) {
    do {
        try validator.validate(node)
        recordIssue("expected tagged validation to fail")
    } catch let collection as PureYAML.Validation.Issue.Collection {
        body(collection)
    } catch {
        recordIssue("expected validation issue collection, got \(error)")
    }
}
