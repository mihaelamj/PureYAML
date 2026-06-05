@testable import PureYAML
import Testing

@Suite("Merge Key Compatibility")
struct MergeKeyCompatibilityTests {
    @Test("Expands a scalar merge key from an anchored mapping")
    func test_scalarMergeKeyExpandsAnchoredMapping() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            defaults: &defaults {enabled: true, retries: 3}
            service:
              <<: *defaults
              name: API
            """,
        ))
        let service = requireMapping(root?["service"], "expected service mapping")

        #expect(service?.pairs == [
            .init(key: "enabled", value: .bool(true)),
            .init(key: "retries", value: .int(3)),
            .init(key: "name", value: .string("API")),
        ])
        #expect(service?["enabled"] == .bool(true))
        #expect(service?["retries"] == .int(3))
        #expect(service?["name"] == .string("API"))
        #expect(service?["<<"] == nil)
        #expect(PureYAML.Validation.Validator().collect(.mapping(root ?? .init())) == .init())
    }

    @Test("Expands merge sequence values with first source precedence and local overrides")
    func test_mergeSequencePrecedenceAndLocalOverrides() throws {
        let root = try requireSequence(PureYAML.parse(
            """
            - &BIG {r: 10}
            - &LEFT {x: 0, y: 2}
            - &SMALL {r: 1}
            - <<: [*BIG, *LEFT, *SMALL]
              x: 1
              label: center/big
            """,
        ))
        let merged = requireMapping(root?.last, "expected merged mapping")

        #expect(merged?.pairs == [
            .init(key: "r", value: .int(10)),
            .init(key: "y", value: .int(2)),
            .init(key: "x", value: .int(1)),
            .init(key: "label", value: .string("center/big")),
        ])
        #expect(merged?["r"] == .int(10))
        #expect(merged?["x"] == .int(1))
        #expect(merged?["y"] == .int(2))
        #expect(merged?["<<"] == nil)
    }

    @Test("Expands a merge value alias that resolves to a sequence of mappings")
    func test_mergeValueAliasResolvesToSequenceOfMappings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            left: &left {x: 1}
            right: &right {y: 2}
            sources: &sources [*left, *right]
            service:
              <<: *sources
              name: API
            """,
        ))
        let service = requireMapping(root?["service"], "expected service mapping")

        #expect(service?.pairs == [
            .init(key: "x", value: .int(1)),
            .init(key: "y", value: .int(2)),
            .init(key: "name", value: .string("API")),
        ])
    }

    @Test("Preserves duplicate local keys after merge expansion for validation")
    func test_mergeExpansionPreservesDuplicateLocalKeysForValidation() throws {
        let value = try PureYAML.parse(
            """
            defaults: &defaults {retries: 3, timeoutSeconds: 30}
            service:
              <<: *defaults
              retries: 5
              name: API
              name: Backend
            """,
        )
        let result = PureYAML.Validation.Validator().collect(value)
        let expectedIssues = [
            PureYAML.Validation.Issue(
                severity: .error,
                reason: "Duplicate mapping key 'name'",
                path: .init([.key("service"), .key("name")]),
            ),
        ]

        #expect(result.issues == expectedIssues)
        #expect(result.errors == expectedIssues)
        expectValidationError(value) { collection in
            #expect(collection.issues == expectedIssues)
            #expect(collection.description == "error: Duplicate mapping key 'name' at $.service.name")
        }

        let root = requireMapping(value, "expected root mapping")
        let service = requireMapping(root?["service"], "expected service mapping")
        #expect(service?.pairs.map(\.key) == ["timeoutSeconds", "retries", "name", "name"])
        #expect(service?["retries"] == .int(5))
    }

    @Test("Keeps quoted and explicit string merge-like keys ordinary")
    func test_quotedAndStringTaggedMergeKeysRemainOrdinary() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            quoted:
              "<<": literal
            tagged:
              ? !!str <<
              : literal
            """,
        ))
        let quoted = requireMapping(root?["quoted"], "expected quoted mapping")
        let tagged = requireMapping(root?["tagged"], "expected tagged mapping")

        #expect(quoted?.pairs == [
            .init(key: "<<", value: .string("literal")),
        ])
        #expect(tagged?.pairs == [
            .init(key: "<<", value: .string("literal")),
        ])
        #expect(quoted?["<<"] == .string("literal"))
        #expect(tagged?["<<"] == .string("literal"))
    }

    @Test("Expands explicit merge-tagged keys")
    func test_explicitMergeTaggedKeyExpands() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            defaults: &defaults {enabled: true}
            service:
              !!merge <<: *defaults
              name: API
            """,
        ))
        let service = requireMapping(root?["service"], "expected service mapping")

        #expect(service?.pairs == [
            .init(key: "enabled", value: .bool(true)),
            .init(key: "name", value: .string("API")),
        ])
        #expect(service?["<<"] == nil)
    }

    @Test("Rejects scalar merge values exactly")
    func test_scalarMergeValueFailsExactly() {
        expectParseError(
            """
            service:
              <<: nope
            """,
            .invalidMergeValue(line: 2, column: 7),
        )
    }

    @Test("Rejects non-mapping merge sequence entries exactly")
    func test_nonMappingMergeSequenceEntryFailsExactly() {
        expectParseError(
            """
            defaults: &defaults {enabled: true}
            service:
              <<: [*defaults, nope]
            """,
            .invalidMergeValue(line: 3, column: 19),
        )
    }

    @Test("Rejects nested merge sequence entries exactly")
    func test_nestedMergeSequenceEntryFailsExactly() {
        expectParseError(
            """
            service:
              <<: [[{enabled: true}]]
            """,
            .invalidMergeValue(line: 2, column: 8),
        )
    }
}

private func requireMapping(
    _ value: PureYAML.Model.Value?,
    _ message: String,
) -> PureYAML.Model.Mapping? {
    guard case let .mapping(mapping)? = value else {
        recordIssue(message)
        return nil
    }
    return mapping
}
