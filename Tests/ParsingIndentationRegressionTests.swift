@testable import PureYAML
import Testing

@Suite("Parsing Indentation Regressions")
struct ParsingIndentationRegressionTests {
    @Test("Parses compact sequence item mappings without swallowing lower-column siblings")
    func test_compactSequenceItemMappingsDoNotSwallowLowerColumnSiblings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            patches:
            - path: patch.yaml
            namePrefix: demo-

            vars:
            - name: WORDPRESS_SERVICE
              objref:
                kind: Service
            """,
        ))

        let patch = root?.sequence("patches")?.first?.mapping
        let variable = root?.sequence("vars")?.first?.mapping

        #expect(patch?["path"] == .string("patch.yaml"))
        #expect(patch?["namePrefix"] == nil)
        #expect(root?["namePrefix"] == .string("demo-"))
        #expect(variable?["name"] == .string("WORDPRESS_SERVICE"))
        #expect(variable?.mapping("objref")?["kind"] == .string("Service"))
        #expect(root?["missing"] == nil)
    }

    @Test("Parses compact sequence item mappings after indentless sequence values")
    func test_compactSequenceItemMappingsAfterIndentlessSequenceValues() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            spec:
              containers:
              - command:
                - runner.sh
                - ./scripts/ci-apidiff.sh
                image: gcr.io/k8s-staging-test-infra/kubekins-e2e
                resources:
                  requests:
                    cpu: 6000m
            """,
        ))

        let container = root?.mapping("spec")?.sequence("containers")?.first?.mapping
        #expect(container?.sequence("command") == [
            .string("runner.sh"),
            .string("./scripts/ci-apidiff.sh"),
        ])
        #expect(container?["image"] == .string("gcr.io/k8s-staging-test-infra/kubekins-e2e"))
        #expect(container?.mapping("resources")?.mapping("requests")?["cpu"] == .string("6000m"))
        #expect(container?["missing"] == nil)
    }

    @Test("Parses lower-column mapping siblings after nested compact sequence item mappings")
    func test_lowerColumnMappingSiblingsAfterNestedCompactSequenceItemMappings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            presubmits:
              org/repo:
              - name: first
                spec:
                  containers:
                  - command:
                    - runner.sh
                    resources:
                      requests:
                        cpu: 6000m
                      limits:
                        memory: 2Gi
                annotations:
                  testgrid-dashboards: core
              - name: second
                cluster: build
            """,
        ))

        let jobs = root?.mapping("presubmits")?.sequence("org/repo")
        let first = jobs?.first?.mapping
        let second = jobs?.dropFirst().first?.mapping
        let container = first?.mapping("spec")?.sequence("containers")?.first?.mapping

        #expect(container?.sequence("command") == [.string("runner.sh")])
        #expect(container?.mapping("resources")?.mapping("requests")?["cpu"] == .string("6000m"))
        #expect(container?.mapping("resources")?.mapping("limits")?["memory"] == .string("2Gi"))
        #expect(first?.mapping("annotations")?["testgrid-dashboards"] == .string("core"))
        #expect(second?["name"] == .string("second"))
        #expect(second?["cluster"] == .string("build"))
        #expect(first?["missing"] == nil)
    }

    @Test("Parses indentless sequence values followed by flow siblings")
    func test_indentlessSequenceValuesFollowedByFlowSiblings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            approveSignerNames:
            - issuers.cert-manager.io/*
            - clusterissuers.cert-manager.io/*
            extraArgs: []
            """,
        ))

        #expect(root?.sequence("approveSignerNames") == [
            .string("issuers.cert-manager.io/*"),
            .string("clusterissuers.cert-manager.io/*"),
        ])
        #expect(root?.sequence("extraArgs") == [])
        #expect(root?["missing"] == nil)
    }

    @Test("Parses nested block sequence values followed by mapping siblings")
    func test_nestedBlockSequenceValuesFollowedByMappingSiblings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            sort_by:
            - - 123
              - asc
            - - 456
              - desc
            group_by:
            - 123
            vertical_group_by:
            - 456
            """,
        ))

        #expect(root?.sequence("sort_by") == [
            .sequence([.int(123), .string("asc")]),
            .sequence([.int(456), .string("desc")]),
        ])
        #expect(root?.sequence("group_by") == [.int(123)])
        #expect(root?.sequence("vertical_group_by") == [.int(456)])
        #expect(root?["missing"] == nil)
    }

    @Test("Parses explicit block scalar indentation indicators")
    func test_explicitBlockScalarIndentationIndicators() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            example:
              value: |2
                  MMM.           .MMM
                   MMMMMMMMMMMMMMMMMMM
                MMMMMMMMMMMMMMMMMMMMM   | Avoid administrative distraction. |
              next: done
            """,
        ))

        #expect(
            root?.mapping("example")?["value"] ==
                .string("  MMM.           .MMM\n   MMMMMMMMMMMMMMMMMMM\nMMMMMMMMMMMMMMMMMMMMM   | Avoid administrative distraction. |\n"),
        )
        #expect(root?.mapping("example")?["next"] == .string("done"))
        #expect(root?.mapping("example")?["missing"] == nil)
    }

    @Test("Parses sequence item mappings after nested values")
    func test_sequenceItemMappingsAfterNestedValues() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            containers:
              - command:
                  - sleep
                  - "3600"
                image: busybox
                name: worker
            """,
        ))

        let containers = requireSequence(root?["containers"])
        guard let firstContainer = containers?.first else {
            recordIssue("expected first container")
            return
        }
        let container = requireMapping(firstContainer)

        #expect(container?["command"] == .sequence([
            .string("sleep"),
            .string("3600"),
        ]))
        #expect(container?["image"] == .string("busybox"))
        #expect(container?["name"] == .string("worker"))
    }

    @Test("Parses sequence item mapping siblings after deep nested mapping values")
    func test_sequenceItemMappingSiblingsAfterDeepNestedMappingValues() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            runs:
            - tool:
                driver:
                  name: CodeQL
                  rules:
                  - id: js/unused-local-variable
                    name: js/unused-local-variable
              results:
              - guid: 326aa09f
                message:
                  text: Unused variable foo.
            """,
        ))

        let run = root?.sequence("runs")?.first?.mapping
        let driver = run?.mapping("tool")?.mapping("driver")
        let rule = driver?.sequence("rules")?.first?.mapping
        let result = run?.sequence("results")?.first?.mapping

        #expect(driver?["name"] == .string("CodeQL"))
        #expect(rule?["id"] == .string("js/unused-local-variable"))
        #expect(rule?["name"] == .string("js/unused-local-variable"))
        #expect(result?["guid"] == .string("326aa09f"))
        #expect(result?.mapping("message")?["text"] == .string("Unused variable foo."))
        #expect(run?["missing"] == nil)
    }
}
