import Foundation
@testable import PureYAML
import Testing

@Suite("Real YAML Corpus")
struct RealYAMLCorpusTests {
    @Test("Corpus manifest matches vendored fixture files")
    func test_corpusManifestMatchesVendoredFixtureFiles() throws {
        let manifest = try RealYAMLCorpusManifest.load()

        #expect(manifest.version == 1)
        #expect(manifest.seeds.count >= 100)
        #expect(manifest.seeds.count(where: { $0.tier == "default" }) == 10)
        #expect(manifest.seeds.count(where: { $0.tier == "full" }) >= 90)
        #expect(Set(manifest.seeds.map(\.id)).count == manifest.seeds.count)

        for seed in manifest.seeds {
            let source = try seed.load()
            #expect(source.utf8.count == seed.byteCount)
            #expect(source.count(where: { $0 == "\n" }) == seed.lineCount)
            #expect(seed.commit.count == 40)
            #expect(seed.rawURL.contains(seed.commit))
            #expect(seed.rawURL.contains(seed.sourcePath))
        }
    }

    @Test("Full real corpus parses validates and round trips when enabled")
    func test_fullRealCorpusParsesValidatesAndRoundTripsWhenEnabled() throws {
        guard ProcessInfo.processInfo.environment["PUREYAML_RUN_FULL_CORPUS"] == "1" else {
            return
        }

        let manifest = try RealYAMLCorpusManifest.load()
        for seed in manifest.seeds {
            let source = try seed.load()
            let documents: [PureYAML.Stream.Document]
            do {
                documents = try PureYAML.parseStream(source)
            } catch {
                recordIssue("\(seed.id): parse failed with \(error)")
                continue
            }

            let issues = PureYAML.Validation.Validator().collect(documents)
            let issueDescriptions = issues.issues.map(\.description).joined(separator: "\n")
            #expect(issues == PureYAML.Stream.Result(), "\(seed.id): \(issueDescriptions)")
            guard seed.expectedRoundTrip == "success" else {
                continue
            }

            let dumped = PureYAML.dump(documents)
            do {
                let reparsed = try PureYAML.parseStream(dumped)
                #expect(reparsed == documents, "\(seed.id): parse/dump/parse changed the document stream")
            } catch {
                recordIssue("\(seed.id): dumped YAML failed to parse with \(error)")
            }
        }
    }
}

private struct RealYAMLCorpusManifest {
    var version: Int
    var seeds: [RealYAMLCorpusSeed]

    static func load() throws -> Self {
        let url = try #require(Bundle.module.url(
            forResource: "real-yaml-corpus",
            withExtension: "yaml",
            subdirectory: "Fixtures",
        ))
        let value = try PureYAML.parse(String(contentsOf: url, encoding: .utf8))
        let root = try #require(value.mapping)
        let version = try #require(root["version"]?.intValue)
        let seedValues = try #require(root.sequence("seeds"))
        return try RealYAMLCorpusManifest(
            version: version,
            seeds: seedValues.map(RealYAMLCorpusSeed.init(value:)),
        )
    }
}

private struct RealYAMLCorpusSeed {
    var id: String
    var localPath: String
    var category: String
    var size: String
    var tier: String
    var expectedParse: String
    var expectedValidation: String
    var expectedRoundTrip: String
    var byteCount: Int
    var lineCount: Int
    var repository: String
    var commit: String
    var sourcePath: String
    var rawURL: String
    var license: String

    init(value: PureYAML.Model.Value) throws {
        let mapping = try #require(value.mapping)
        id = try mapping.requiredString("id")
        localPath = try mapping.requiredString("localPath")
        category = try mapping.requiredString("category")
        size = try mapping.requiredString("size")
        tier = try mapping.requiredString("tier")
        expectedParse = try mapping.requiredString("expectedParse")
        expectedValidation = try mapping.requiredString("expectedValidation")
        expectedRoundTrip = try mapping.requiredString("expectedRoundTrip")
        byteCount = try mapping.requiredInt("byteCount")
        lineCount = try mapping.requiredInt("lineCount")
        repository = try mapping.requiredString("repository")
        commit = try mapping.requiredString("commit")
        sourcePath = try mapping.requiredString("sourcePath")
        rawURL = try mapping.requiredString("rawURL")
        license = try mapping.requiredString("license")
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
        try #require(self[key]?.stringValue)
    }

    func requiredInt(_ key: String) throws -> Int {
        try #require(self[key]?.intValue)
    }
}

private extension PureYAML.Model.Value {
    var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        return value
    }

    var intValue: Int? {
        guard case let .int(value) = self else {
            return nil
        }
        return value
    }
}
