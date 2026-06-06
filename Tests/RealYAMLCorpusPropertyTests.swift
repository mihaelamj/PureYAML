import Foundation
@testable import PureYAML
import Testing

@Suite("Real YAML Corpus Properties")
struct RealYAMLCorpusPropertyTests {
    @Test("Generated valid YAML documents parse dump and parse stably")
    func test_generatedValidYAMLDocumentsParseDumpAndParseStably() throws {
        var generator = DeterministicGenerator(seed: 0x5055_5941_4D4C)

        for index in 0 ..< 100 {
            let yaml = generator.validYAMLDocument(index: index)
            let documents = try PureYAML.parseStream(yaml)
            try PureYAML.validate(documents)

            let dumped = PureYAML.dump(documents)
            let reparsed = try PureYAML.parseStream(dumped)

            #expect(reparsed == documents, "generated case \(index) changed after parse/dump/parse")
        }
    }

    @Test("Real seed mutations return structured diagnostics without crashing")
    func test_realSeedMutationsReturnStructuredDiagnosticsWithoutCrashing() throws {
        let seeds = try PropertyCorpusSeed.loadAll()
            .filter { $0.tier == "default" }
            .prefix(10)

        for seed in seeds {
            let source = try seed.load()
            for mutation in PropertyMutation.allCases {
                let mutated = mutation.apply(to: source, seedID: seed.id)
                let report = PureYAML.diagnosticValidationReport(mutated, file: "\(seed.id)-\(mutation.rawValue).yaml")

                #expect(!report.diagnostics.isEmpty, "\(seed.id) \(mutation.rawValue) produced no diagnostics")
                #expect(report.diagnostics.allSatisfy { $0.kind == .parse })
                let codes = report.diagnostics.map { $0.code ?? "nil" }.joined(separator: ",")
                #expect(
                    report.diagnostics.contains { $0.code == mutation.expectedCode },
                    "\(seed.id) \(mutation.rawValue) expected \(mutation.expectedCode), got \(codes)",
                )
                #expect(!report.description.isEmpty)
                #expect(!report.jsonDescription(title: "Generated Corpus Mutation").isEmpty)
            }
        }
    }
}

private struct DeterministicGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func validYAMLDocument(index: Int) -> String {
        let service = "service-\(index)-\(nextInt(10000))"
        let replicas = nextInt(5) + 1
        let enabled = nextInt(2) == 0 ? "true" : "false"
        let threshold = "\(nextInt(100)).\(nextInt(10))"
        let firstPort = 8000 + nextInt(100)
        let secondPort = 9000 + nextInt(100)
        return """
        ---
        metadata:
          name: \(service)
          labels: {app: pureyaml, generated: "true"}
        spec:
          replicas: \(replicas)
          enabled: \(enabled)
          threshold: \(threshold)
          ports:
            - name: http
              port: \(firstPort)
            - name: metrics
              port: \(secondPort)
          env:
            LOG_LEVEL: "info"
            FEATURE_FLAG: "\(enabled)"
        """
    }

    private mutating func nextInt(_ upperBound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 32) % UInt64(upperBound))
    }
}

private enum PropertyMutation: String, CaseIterable {
    case missingMappingSpace
    case tabIndentation
    case missingSequenceSpace
    case unterminatedQuotedString
    case undefinedAlias

    var expectedCode: String {
        switch self {
        case .missingMappingSpace:
            "missingMappingSpace"
        case .tabIndentation:
            "tabIndentation"
        case .missingSequenceSpace:
            "missingSequenceSpace"
        case .unterminatedQuotedString:
            "unterminatedQuotedString"
        case .undefinedAlias:
            "undefinedAlias"
        }
    }

    func apply(to source: String, seedID: String) -> String {
        let sample = source.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(3)
            .joined(separator: "\n")
        if self == .unterminatedQuotedString {
            return """
            # mutation-source: \(seedID)
            sample: |
              \(sample.replacingOccurrences(of: "\n", with: "\n  "))
            mutation: "unterminated scalar
            """
        }

        let prefix = switch self {
        case .missingMappingSpace:
            "mutation:Missing mapping space"
        case .tabIndentation:
            "\tmutation: tab indentation"
        case .missingSequenceSpace:
            "-mutation sequence marker"
        case .unterminatedQuotedString:
            "mutation: \"unterminated scalar"
        case .undefinedAlias:
            "mutation: *undefinedMutationAlias"
        }
        return """
        # mutation-source: \(seedID)
        \(prefix)
        sample: |
          \(sample.replacingOccurrences(of: "\n", with: "\n  "))
        """
    }
}

private struct PropertyCorpusSeed {
    var id: String
    var localPath: String
    var tier: String

    static func loadAll() throws -> [Self] {
        let url = try #require(Bundle.module.url(
            forResource: "real-yaml-corpus",
            withExtension: "yaml",
            subdirectory: "Fixtures",
        ))
        let manifest = try PureYAML.parse(String(contentsOf: url, encoding: .utf8))
        let root = try #require(manifest.mapping)
        let seedValues = try #require(root.sequence("seeds"))
        return try seedValues.map { value in
            let mapping = try #require(value.mapping)
            return try PropertyCorpusSeed(
                id: mapping.requiredString("id"),
                localPath: mapping.requiredString("localPath"),
                tier: mapping.requiredString("tier"),
            )
        }
    }

    func load() throws -> String {
        let url = try #require(Bundle.module.url(
            forResource: resourceName,
            withExtension: resourceExtension,
            subdirectory: resourceSubdirectory,
        ))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private var resourceSubdirectory: String {
        let directory = localPath.split(separator: "/").dropLast().joined(separator: "/")
        return directory.isEmpty ? "Fixtures" : "Fixtures/\(directory)"
    }

    private var resourceFileName: String {
        String(localPath.split(separator: "/").last ?? "")
    }

    private var resourceName: String {
        guard let dotIndex = resourceFileName.lastIndex(of: ".") else {
            return resourceFileName
        }
        return String(resourceFileName[..<dotIndex])
    }

    private var resourceExtension: String {
        guard let dotIndex = resourceFileName.lastIndex(of: ".") else {
            return ""
        }
        return String(resourceFileName[resourceFileName.index(after: dotIndex)...])
    }
}

private extension PureYAML.Model.Mapping {
    func requiredString(_ key: String) throws -> String {
        guard case let .string(value)? = self[key] else {
            throw PropertyCorpusError("missing string key \(key)")
        }
        return value
    }
}

private struct PropertyCorpusError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}
