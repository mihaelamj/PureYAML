@testable import PureYAML
import Testing

@Suite("Parsing")
struct ParsingTests {
    struct ScalarCase {
        var yaml: String
        var expected: PureYAML.Model.Value
    }

    @Test("Parses block mappings with common scalars")
    func test_blockMappingWithCommonScalars() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            openapi: 3.1.0
            title: "Example API"
            active: true
            retries: 3
            ratio: 3.1
            missing: null
            """,
        ))

        #expect(root?["openapi"] == .string("3.1.0"))
        #expect(root?["title"] == .string("Example API"))
        #expect(root?["active"] == .bool(true))
        #expect(root?["retries"] == .int(3))
        #expect(root?["ratio"] == .double(3.1))
        #expect(root?["missing"] == .null)
        #expect(root?["unknown"] == nil)
    }

    @Test("Parses scalar spellings", arguments: [
        ScalarCase(yaml: "value:", expected: .null),
        ScalarCase(yaml: "value: ~", expected: .null),
        ScalarCase(yaml: "value: NULL", expected: .null),
        ScalarCase(yaml: "value: True", expected: .bool(true)),
        ScalarCase(yaml: "value: FALSE", expected: .bool(false)),
        ScalarCase(yaml: "value: -7", expected: .int(-7)),
        ScalarCase(yaml: "value: 1e3", expected: .double(1000)),
        ScalarCase(yaml: "value: plain text", expected: .string("plain text")),
    ])
    func test_scalarSpellings(testCase: ScalarCase) throws {
        let root = try requireMapping(PureYAML.parse(testCase.yaml))

        #expect(root?["value"] == testCase.expected)
    }

    @Test("Parses quoted strings and escapes")
    func test_quotedStringsAndEscapes() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            double: "line\\nnext\\tend"
            single: 'it''s'
            slash: "a\\/b"
            """,
        ))

        #expect(root?["double"] == .string("line\nnext\tend"))
        #expect(root?["single"] == .string("it's"))
        #expect(root?["slash"] == .string("a/b"))
    }

    @Test("Ignores comments outside quoted strings")
    func test_commentsOutsideQuotedStrings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            title: "Keep # inside" # remove outside
            single: 'Keep # inside' # remove outside
            plain: value#kept # remove outside
            """,
        ))

        #expect(root?["title"] == .string("Keep # inside"))
        #expect(root?["single"] == .string("Keep # inside"))
        #expect(root?["plain"] == .string("value#kept"))
        #expect(root?["plain"] != .string("value"))
    }

    @Test("Parses nested mappings and sequences")
    func test_nestedMappingsAndSequences() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            paths:
              /users:
                get:
                  tags:
                    - Users
                    - Public
            """,
        ))

        guard
            case let .mapping(paths)? = root?["paths"],
            case let .mapping(users)? = paths["/users"],
            case let .mapping(get)? = users["get"],
            case let .sequence(tags)? = get["tags"]
        else {
            recordIssue("expected nested tags")
            return
        }
        #expect(tags == [.string("Users"), .string("Public")])
    }

    @Test("Parses sequences of mappings")
    func test_sequenceOfMappings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            servers:
              - url: /
                description: Default
              - url: https://example.com
                description: Production
            """,
        ))

        guard
            let servers = requireSequence(root?["servers"]),
            servers.count == 2,
            case let .mapping(first) = servers[0],
            case let .mapping(second) = servers[1]
        else {
            recordIssue("expected server mappings")
            return
        }

        #expect(first["url"] == .string("/"))
        #expect(first["description"] == .string("Default"))
        #expect(second["url"] == .string("https://example.com"))
        #expect(second["description"] == .string("Production"))
    }

    @Test("Parses indentless sequences as mapping values")
    func test_indentlessSequencesAsMappingValues() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            resources:
            - wordpress
            - mysql
            patches:
            - path: patch.yaml
            """,
        ))

        #expect(root?["resources"] == .sequence([
            .string("wordpress"),
            .string("mysql"),
        ]))
        #expect(root?["patches"] == .sequence([
            .mapping(.init([
                .init(key: "path", value: .string("patch.yaml")),
            ])),
        ]))
        #expect(root?["missing"] == nil)
    }

    @Test("Parses nested indentless sequence values followed by mapping siblings")
    func test_nestedIndentlessSequenceValuesInsideMappingsFollowedBySiblings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            spec:
              names:
                categories:
                - cert-manager
                kind: Certificate
                shortNames:
                - cert
                - certs
                singular: certificate
            """,
        ))

        let names = root?.mapping("spec")?.mapping("names")
        #expect(names?.sequence("categories") == [.string("cert-manager")])
        #expect(names?["kind"] == .string("Certificate"))
        #expect(names?.sequence("shortNames") == [.string("cert"), .string("certs")])
        #expect(names?["singular"] == .string("certificate"))
        #expect(names?["missing"] == nil)
    }

    @Test("Parses indentless sequence values inside sequence item mappings")
    func test_indentlessSequenceValuesInsideSequenceItemMappings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            presubmits:
              kubernetes-sigs/cluster-api:
              - name: pull-cluster-api-build-release-1-13
                branches:
                - ^release-1.13$
                spec:
                  containers:
                  - image: gcr.io/k8s-staging-test-infra/kubekins-e2e
                    command:
                    - runner.sh
                    - ./scripts/ci-build.sh
                annotations:
                  testgrid-dashboards: cluster-api-core-1.13
            """,
        ))

        let jobs = root?.mapping("presubmits")?.sequence("kubernetes-sigs/cluster-api")
        let job = jobs?.first?.mapping
        let container = job?.mapping("spec")?.sequence("containers")?.first?.mapping

        #expect(job?["name"] == .string("pull-cluster-api-build-release-1-13"))
        #expect(job?.sequence("branches") == [.string("^release-1.13$")])
        #expect(container?["image"] == .string("gcr.io/k8s-staging-test-infra/kubekins-e2e"))
        #expect(container?.sequence("command") == [
            .string("runner.sh"),
            .string("./scripts/ci-build.sh"),
        ])
        #expect(job?.mapping("annotations")?["testgrid-dashboards"] == .string("cluster-api-core-1.13"))
        #expect(job?["missing"] == nil)
    }

    @Test("Parses top-level sequences")
    func test_topLevelSequences() throws {
        let value = try PureYAML.parse(
            """
            - one
            - 2
            - false
            """,
        )

        #expect(value == .sequence([
            .string("one"),
            .int(2),
            .bool(false),
        ]))
    }

    @Test("Parses flow collections through the event composer")
    func test_flowCollections() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            values: [one, 2, false, {name: Example}]
            """,
        ))

        guard
            let values = requireSequence(root?["values"]),
            values.count == 4,
            case let .mapping(mapping) = values[3]
        else {
            recordIssue("expected flow collection values")
            return
        }
        #expect(values[0] == .string("one"))
        #expect(values[1] == .int(2))
        #expect(values[2] == .bool(false))
        #expect(mapping["name"] == .string("Example"))
    }

    @Test("Parses block scalars through the event composer")
    func test_blockScalars() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            text: |
              one
              two
            stripped: |-
              one
              two
            folded: >
              one
              two
            """,
        ))

        #expect(root?["text"] == .string("one\ntwo\n"))
        #expect(root?["stripped"] == .string("one\ntwo"))
        #expect(root?["folded"] == .string("one two\n"))
    }
}
