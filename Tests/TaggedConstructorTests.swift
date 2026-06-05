@testable import PureYAML
import Testing

@Suite("Tagged Constructor")
struct TaggedConstructorTests {
    @Test("Constructs a custom scalar tag exactly")
    func test_constructsCustomScalarTagExactly() throws {
        let tag = PureYAML.Tagged.Tag("!Env")
        let node = try PureYAML.parseTagged("!Env DATABASE_URL")
        let constructor = PureYAML.Tagged.Constructor<String>()
            .constructingScalar(tag: tag) { scalar, context in
                #expect(context.path == .root)
                #expect(context.subject == node)
                return "env:\(scalar.rawValue)"
            }

        #expect(try constructor.construct(node) == "env:DATABASE_URL")
    }

    @Test("Constructs a custom sequence tag without changing element order")
    func test_constructsCustomSequenceTagWithoutChangingElementOrder() throws {
        let tag = PureYAML.Tagged.Tag("!Words")
        let node = try PureYAML.parseTagged("!Words [one, two, three]")
        let constructor = PureYAML.Tagged.Constructor<[String]>()
            .constructingSequence(tag: tag) { sequence, _ in
                try sequence.values.map { node in
                    let scalar = try requireTaggedScalar(node)
                    return scalar.rawValue
                }
            }

        #expect(try constructor.construct(node) == ["one", "two", "three"])
    }

    @Test("Constructs a custom mapping tag without dictionary collapse")
    func test_constructsCustomMappingTagWithoutDictionaryCollapse() throws {
        let tag = PureYAML.Tagged.Tag("!Service")
        let node = try PureYAML.parseTagged(
            """
            !Service
            name: api
            name: worker
            replicas: 2
            """,
        )
        let constructor = PureYAML.Tagged.Constructor<[String]>()
            .constructingMapping(tag: tag) { mapping, _ in
                mapping.pairs.map(\.key)
            }

        #expect(try constructor.construct(node) == ["name", "name", "replicas"])
    }

    @Test("Rejects unsupported constructors exactly")
    func test_rejectsUnsupportedConstructorsExactly() throws {
        let tag = PureYAML.Tagged.Tag("!Env")
        let node = try PureYAML.parseTagged("!Env DATABASE_URL")
        let expected = PureYAML.Tagged.ConstructionError.noConstructor(
            tag: tag,
            kind: .scalar,
            path: .root,
        )

        expectConstructionError(expected, description: "No constructor for tag '!Env' on scalar at $") {
            try PureYAML.Tagged.Constructor<String>().construct(node)
        }
    }

    @Test("Rejects untagged nodes without a fallback exactly")
    func test_rejectsUntaggedNodesWithoutFallbackExactly() throws {
        let node = try PureYAML.parseTagged("DATABASE_URL")
        let expected = PureYAML.Tagged.ConstructionError.noConstructor(
            tag: nil,
            kind: .scalar,
            path: .root,
        )

        expectConstructionError(expected, description: "No constructor for untagged scalar at $") {
            try PureYAML.Tagged.Constructor<String>().construct(node)
        }
    }

    @Test("Rejects tags registered for multiple wrong kinds exactly")
    func test_rejectsTagsRegisteredForMultipleWrongKindsExactly() throws {
        let tag = PureYAML.Tagged.Tag("!Flexible")
        let node = try PureYAML.parseTagged("!Flexible {name: api}")
        let expected = PureYAML.Tagged.ConstructionError.kindMismatch(
            tag: tag,
            expected: [.scalar, .sequence],
            actual: .mapping,
            path: .root,
        )
        let constructor = PureYAML.Tagged.Constructor<String>()
            .constructingScalar(tag: tag) { scalar, _ in
                scalar.rawValue
            }
            .constructingSequence(tag: tag) { sequence, _ in
                "\(sequence.values.count)"
            }

        expectConstructionError(
            expected,
            description: "Constructor for tag '!Flexible' expects scalar or sequence, found mapping at $",
        ) {
            try constructor.construct(node)
        }
    }

    @Test("Uses explicit fallback for unmatched tagged nodes")
    func test_usesExplicitFallbackForUnmatchedTaggedNodes() throws {
        let node = try PureYAML.parseTagged("!Name Mihaela")
        let constructor = PureYAML.Tagged.Constructor<String>()
            .fallingBackTo { node, context in
                #expect(context.path == .root)
                #expect(context.subject == node)
                return "fallback:\(node.kind)"
            }

        #expect(try constructor.construct(node) == "fallback:scalar")
    }

    @Test("Rejects wrong node kind with recursive path context exactly")
    func test_rejectsWrongNodeKindWithRecursivePathContextExactly() throws {
        let boxTag = PureYAML.Tagged.Tag("!Box")
        let envTag = PureYAML.Tagged.Tag("!Env")
        let node = try PureYAML.parseTagged("!Box {value: !Env {name: DATABASE_URL}}")
        let expected = PureYAML.Tagged.ConstructionError.kindMismatch(
            tag: envTag,
            expected: [.scalar],
            actual: .mapping,
            path: .init([.key("value")]),
        )
        let constructor = PureYAML.Tagged.Constructor<String>()
            .constructingScalar(tag: envTag) { scalar, _ in
                scalar.rawValue
            }
            .constructingMapping(tag: boxTag) { mapping, context in
                guard let value = mapping["value"] else {
                    throw TaggedConstructorFixtureError.invalidShape("missing value")
                }
                return try context.construct(value, at: context.path.appending(.key("value")))
            }

        expectConstructionError(
            expected,
            description: "Constructor for tag '!Env' expects scalar, found mapping at $.value",
        ) {
            try constructor.construct(node)
        }
    }

    @Test("Propagates invalid tagged values from caller handlers exactly")
    func test_propagatesInvalidTaggedValuesFromCallerHandlersExactly() throws {
        let tag = PureYAML.Tagged.Tag("!Port")
        let node = try PureYAML.parseTagged("!Port nope")
        let constructor = PureYAML.Tagged.Constructor<Int>()
            .constructingScalar(tag: tag) { scalar, context in
                guard case let .int(port) = scalar.value else {
                    throw TaggedConstructorFixtureError.invalidPort(
                        rawValue: scalar.rawValue,
                        path: context.path,
                    )
                }
                return port
            }

        expectTaggedConstructorFixtureError(.invalidPort(rawValue: "nope", path: .root)) {
            try constructor.construct(node)
        }
    }

    @Test("Explicit model fallback preserves duplicate keys and erases tags")
    func test_explicitModelFallbackPreservesDuplicateKeysAndErasesTags() throws {
        let node = try PureYAML.parseTagged(
            """
            !Root
            title: one
            title: !Local two
            """,
        )
        let value = try PureYAML.Tagged.Constructor<PureYAML.Model.Value>
            .modelValueErasingTags
            .construct(node)
        let mapping = requireMapping(value)
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Duplicate mapping key 'title'",
                path: .init([.key("title")]),
            ),
        ]

        #expect(mapping?.pairs.map(\.key) == ["title", "title"])
        #expect(mapping?.pairs.map(\.value) == [.string("one"), .string("two")])
        #expect(value == node.modelValueErasingTags)
        #expect(PureYAML.Validation.Validator().collect(value).issues == expectedIssues)
    }

    @Test("Constructors do not run tagged validation implicitly")
    func test_constructorsDoNotRunTaggedValidationImplicitly() throws {
        let node = try PureYAML.parseTagged("!!timestamp 2001-01-23")
        let value = try PureYAML.Tagged.Constructor<PureYAML.Model.Value>
            .modelValueErasingTags
            .construct(node)
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Unsupported built-in tag 'tag:yaml.org,2002:timestamp'",
                path: .root,
            ),
        ]

        #expect(value == .string("2001-01-23"))
        #expect(PureYAML.Tagged.Validator().collect(node).issues == expectedIssues)
    }

    @Test("Tagged construction keeps complex mapping keys out of the tagged layer")
    func test_taggedConstructionKeepsComplexMappingKeysOutOfTheTaggedLayer() {
        expectError(PureYAML.Parsing.ParseError.expectedScalarKey(line: 1, column: 3)) {
            try PureYAML.parseTagged(
                """
                ? [a, b]
                : value
                """,
            )
        }
    }
}

private enum TaggedConstructorFixtureError: Swift.Error, Equatable, CustomStringConvertible {
    case invalidPort(rawValue: String, path: PureYAML.Validation.Path)
    case invalidShape(String)

    var description: String {
        switch self {
        case let .invalidPort(rawValue, path):
            "Invalid port '\(rawValue)' at \(path)"
        case let .invalidShape(message):
            message
        }
    }
}

private func requireTaggedScalar(
    _ node: PureYAML.Tagged.Node?,
    _ message: String = "expected tagged scalar",
) throws -> PureYAML.Tagged.Scalar {
    guard case let .scalar(scalar)? = node else {
        recordIssue(message)
        throw TaggedConstructorFixtureError.invalidShape(message)
    }
    return scalar
}

private func expectConstructionError(
    _ expected: PureYAML.Tagged.ConstructionError,
    description: String,
    operation: () throws -> some Any,
) {
    do {
        _ = try operation()
        recordIssue("expected construction error \(expected)")
    } catch let error as PureYAML.Tagged.ConstructionError {
        #expect(error == expected)
        #expect(error.description == description)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}

private func expectTaggedConstructorFixtureError(
    _ expected: TaggedConstructorFixtureError,
    operation: () throws -> some Any,
) {
    do {
        _ = try operation()
        recordIssue("expected fixture error \(expected)")
    } catch let error as TaggedConstructorFixtureError {
        #expect(error == expected)
        #expect(error.description == expected.description)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}
