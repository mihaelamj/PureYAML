import Foundation
@testable import PureYAML
import Testing

@Suite("Real YAML Fixtures")
struct RealYAMLFixtureTests {
    @Test("Real YAML fixture files match their pinned manifest", arguments: RealYAMLFixture.allCases)
    func test_realYAMLFixtureFilesMatchPinnedManifest(fixture: RealYAMLFixture) throws {
        let source = try fixture.load()

        #expect(source.utf8.count == fixture.byteCount)
        #expect(source.count(where: { $0 == "\n" }) == fixture.lineCount)

        for requiredSubstring in fixture.requiredSubstrings {
            #expect(source.contains(requiredSubstring))
        }
        for forbiddenSubstring in fixture.forbiddenSubstrings {
            #expect(!source.contains(forbiddenSubstring))
        }
    }

    @Test("Parses real YAML fixtures with exact representative values", arguments: RealYAMLFixture.allCases)
    func test_parsesRealYAMLFixturesWithExactRepresentativeValues(fixture: RealYAMLFixture) throws {
        let value = try PureYAML.parse(fixture.load())

        fixture.expectRepresentativeValues(in: value)
        #expect(PureYAML.Validation.Validator().collect(value) == PureYAML.Validation.Result())
    }
}

enum RealYAMLFixture: String, CaseIterable, CustomStringConvertible {
    case certManagerCertificateCRD = "cert-manager-certificate-crd.yaml"
    case certManagerValues = "cert-manager-values.yaml"
    case dockerComposeNginxGolangPostgres = "docker-compose-nginx-golang-postgres.yaml"
    case githubActionsSwiftFormat = "github-actions-swift-format.yml"
    case githubRestAPI = "github-rest-api.yaml"
    case kubernetesSimplePod = "kubernetes-simple-pod.yaml"
    case kustomizeWordPress = "kustomize-wordpress.yaml"
    case openAPIPetstore = "openapi-petstore.yaml"
    case prometheusGoodConfig = "prometheus-conf-good.yml"
    case prowClusterAPIPresubmits = "prow-cluster-api-presubmits.yaml"

    var description: String {
        rawValue
    }

    var lineCount: Int {
        switch self {
        case .certManagerCertificateCRD:
            883
        case .certManagerValues:
            1759
        case .dockerComposeNginxGolangPostgres:
            48
        case .githubActionsSwiftFormat:
            84
        case .githubRestAPI:
            257_280
        case .kubernetesSimplePod:
            12
        case .kustomizeWordPress:
            18
        case .openAPIPetstore:
            119
        case .prometheusGoodConfig:
            481
        case .prowClusterAPIPresubmits:
            427
        }
    }

    var byteCount: Int {
        switch self {
        case .certManagerCertificateCRD:
            44059
        case .certManagerValues:
            65536
        case .dockerComposeNginxGolangPostgres:
            852
        case .githubActionsSwiftFormat:
            3591
        case .githubRestAPI:
            9_549_118
        case .kubernetesSimplePod:
            186
        case .kustomizeWordPress:
            262
        case .openAPIPetstore:
            2768
        case .prometheusGoodConfig:
            11562
        case .prowClusterAPIPresubmits:
            14213
        }
    }

    var requiredSubstrings: [String] {
        switch self {
        case .certManagerCertificateCRD:
            [
                "apiVersion: apiextensions.k8s.io/v1",
                "jsonPath: .status.conditions[?(@.type == \"Ready\")].status",
                "Known condition types are `Ready` and `Issuing`.",
            ]
        case .certManagerValues:
            [
                "installCRDs: false",
                "hostUsers: false",
                "webhook:",
            ]
        case .dockerComposeNginxGolangPostgres:
            [
                "services:",
                "test: [ \"CMD\", \"pg_isready\" ]",
                "file: db/password.txt",
            ]
        case .githubActionsSwiftFormat:
            [
                "name: Pull request",
                "types: [opened, reopened, synchronize, ready_for_review]",
                "run: |",
            ]
        case .githubRestAPI:
            [
                "openapi: 3.1.0",
                "title: GitHub v3 REST API",
                "components:",
            ]
        case .kubernetesSimplePod:
            [
                "kind: Pod",
                "name: pods-simple-container",
            ]
        case .kustomizeWordPress:
            [
                "namePrefix: demo-",
                "name: WORDPRESS_SERVICE",
            ]
        case .openAPIPetstore:
            [
                "title: Swagger Petstore",
                "operationId: listPets",
                "'201':",
            ]
        case .prometheusGoodConfig:
            [
                "scrape_interval: 15s",
                "fallback_scrape_protocol: PrometheusText0.0.4",
                "password: \"multiline\\nmysecret\\ntest\"",
            ]
        case .prowClusterAPIPresubmits:
            [
                "presubmits:",
                "run_if_changed: '^((api|bootstrap|cmd|config|controllers|controlplane|errors|exp|feature|hack|internal|scripts|test|util"
                    + "|webhooks|version)/|main\\.go|go\\.mod|go\\.sum|Dockerfile|Makefile)'",
                "securityContext:",
            ]
        }
    }

    var forbiddenSubstrings: [String] {
        [
            "<<<<<<<",
            "=======",
            ">>>>>>>",
        ]
    }

    func load() throws -> String {
        let url = try #require(Bundle.module.url(
            forResource: resourceName,
            withExtension: resourceExtension,
            subdirectory: "Fixtures/real-yaml",
        ))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func expectRepresentativeValues(in value: PureYAML.Model.Value) {
        switch self {
        case .certManagerCertificateCRD:
            expectCertManagerCertificateCRD(value)
        case .certManagerValues:
            expectCertManagerValues(value)
        case .dockerComposeNginxGolangPostgres:
            expectDockerComposeNginxGolangPostgres(value)
        case .githubActionsSwiftFormat:
            expectGitHubActionsSwiftFormat(value)
        case .githubRestAPI:
            expectGitHubRestAPI(value)
        case .kubernetesSimplePod:
            expectKubernetesSimplePod(value)
        case .kustomizeWordPress:
            expectKustomizeWordPress(value)
        case .openAPIPetstore:
            expectOpenAPIPetstore(value)
        case .prometheusGoodConfig:
            expectPrometheusGoodConfig(value)
        case .prowClusterAPIPresubmits:
            expectProwClusterAPIPresubmits(value)
        }
    }

    private var resourceName: String {
        guard let dotIndex = rawValue.lastIndex(of: ".") else {
            return rawValue
        }
        return String(rawValue[..<dotIndex])
    }

    private var resourceExtension: String {
        guard let dotIndex = rawValue.lastIndex(of: ".") else {
            return ""
        }
        return String(rawValue[rawValue.index(after: dotIndex)...])
    }
}

private func expectCertManagerCertificateCRD(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)

    #expect(root?["apiVersion"] == .string("apiextensions.k8s.io/v1"))
    #expect(root?["kind"] == .string("CustomResourceDefinition"))
    #expect(root?.mapping("metadata")?["name"] == .string("certificates.cert-manager.io"))

    let spec = root?.mapping("spec")
    #expect(spec?.mapping("names")?["kind"] == .string("Certificate"))

    let versions = requireSequence(spec?["versions"])
    let firstVersion = versions?.first?.mapping
    let firstColumn = firstVersion?.sequence("additionalPrinterColumns")?.first?.mapping

    #expect(firstColumn?["name"] == .string("Ready"))
    #expect(firstColumn?["jsonPath"] == .string(".status.conditions[?(@.type == \"Ready\")].status"))
}

private func expectCertManagerValues(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)

    #expect(root?.mapping("global")?.mapping("rbac")?["create"] == .bool(true))
    #expect(root?["installCRDs"] == .bool(false))
    #expect(root?.mapping("crds")?["enabled"] == .bool(false))
    #expect(root?.mapping("crds")?["keep"] == .bool(true))
    #expect(root?["replicaCount"] == .int(1))
    #expect(root?.mapping("webhook")?["timeoutSeconds"] == .int(30))
}

private func expectDockerComposeNginxGolangPostgres(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)
    let services = root?.mapping("services")

    #expect(services?.mapping("backend")?.mapping("build")?["context"] == .string("backend"))
    #expect(services?.mapping("backend")?.mapping("depends_on")?.mapping("db")?["condition"] == .string("service_healthy"))
    #expect(services?.mapping("db")?["image"] == .string("postgres"))
    #expect(services?.mapping("db")?.sequence("healthcheck", "test") == [.string("CMD"), .string("pg_isready")])
    #expect(services?.mapping("proxy")?.sequence("depends_on") == [.string("backend")])
    #expect(root?.mapping("secrets")?.mapping("db-password")?["file"] == .string("db/password.txt"))
}

private func expectGitHubActionsSwiftFormat(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)

    #expect(root?["name"] == .string("Pull request"))
    #expect(root?.mapping("permissions")?["contents"] == .string("read"))
    #expect(root?.mapping("on")?.mapping("pull_request")?.sequence("types") == [
        .string("opened"),
        .string("reopened"),
        .string("synchronize"),
        .string("ready_for_review"),
    ])
    #expect(root?.mapping("concurrency")?["cancel-in-progress"] == .bool(true))
    #expect(
        root?.mapping("jobs")?.mapping("tests")?["uses"] ==
            .string("swiftlang/github-workflows/.github/workflows/swift_package_test.yml@0.0.11"),
    )
    #expect(root?.mapping("jobs")?.mapping("compatibility_check")?.mapping("container")?["image"] == .string("swift:6.2"))
}

private func expectGitHubRestAPI(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)

    #expect(root?["openapi"] == .string("3.1.0"))
    #expect(root?.mapping("info")?["title"] == .string("GitHub v3 REST API"))
    #expect(root?.mapping("info")?["version"] == .string("1.1.4"))

    let firstTag = root?.sequence("tags")?.first?.mapping
    #expect(firstTag?["name"] == .string("actions"))
    #expect(root?.mapping("components")?.mapping("schemas")?.mapping("repository")?.mapping("properties")?.mapping("full_name")?["type"] == .string("string"))
}

private func expectKubernetesSimplePod(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)

    #expect(root?["apiVersion"] == .string("v1"))
    #expect(root?["kind"] == .string("Pod"))
    #expect(root?.mapping("metadata")?["name"] == .string("pods-simple-pod"))

    let container = root?.mapping("spec")?.sequence("containers")?.first?.mapping
    #expect(container?["image"] == .string("busybox"))
    #expect(container?["name"] == .string("pods-simple-container"))
    #expect(container?.sequence("command") == [.string("sleep"), .string("3600")])
}

private func expectKustomizeWordPress(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)

    #expect(root?.sequence("resources") == [.string("wordpress"), .string("mysql")])
    #expect(root?.sequence("patches")?.first?.mapping?["path"] == .string("patch.yaml"))
    #expect(root?["namePrefix"] == .string("demo-"))

    let firstVariable = root?.sequence("vars")?.first?.mapping
    #expect(firstVariable?["name"] == .string("WORDPRESS_SERVICE"))
    #expect(firstVariable?.mapping("objref")?["kind"] == .string("Service"))
    #expect(firstVariable?.mapping("objref")?["name"] == .string("wordpress"))
}

private func expectOpenAPIPetstore(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)

    #expect(root?["openapi"] == .string("3.0.0"))
    #expect(root?.mapping("info")?["title"] == .string("Swagger Petstore"))
    #expect(root?.mapping("paths")?.mapping("/pets")?.mapping("get")?["operationId"] == .string("listPets"))
    #expect(root?.mapping("paths")?.mapping("/pets")?.mapping("post")?.mapping("responses")?["201"] != nil)
    #expect(root?.mapping("components")?.mapping("schemas")?.mapping("Pet")?.sequence("required") == [
        .string("id"),
        .string("name"),
    ])
}

private func expectPrometheusGoodConfig(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)

    #expect(root?.mapping("global")?["scrape_interval"] == .string("15s"))
    #expect(root?.mapping("global")?.mapping("external_labels")?["monitor"] == .string("codelab"))
    #expect(root?.sequence("remote_write")?.first?.mapping?.mapping("oauth2")?["client_id"] == .string("123"))

    let staticTargets = root?
        .sequence("scrape_configs")?.first?
        .mapping?
        .sequence("static_configs")?.first?
        .mapping?
        .sequence("targets")
    #expect(staticTargets == [.string("localhost:9090"), .string("localhost:9191")])
}

private func expectProwClusterAPIPresubmits(_ value: PureYAML.Model.Value) {
    let root = requireMapping(value)
    let jobs = root?.mapping("presubmits")?.sequence("kubernetes-sigs/cluster-api")
    let firstJob = jobs?.first?.mapping

    #expect(firstJob?["name"] == .string("pull-cluster-api-build-release-1-13"))
    #expect(firstJob?["cluster"] == .string("eks-prow-build-cluster"))
    #expect(firstJob?["always_run"] == .bool(true))
    #expect(firstJob?.sequence("branches") == [.string("^release-1.13$")])
    #expect(firstJob?.mapping("spec")?.sequence("containers")?.first?.mapping?["image"] == .string("gcr.io/k8s-staging-test-infra/kubekins-e2e:v20260601-2cbf4bdb47-1.35"))
}
