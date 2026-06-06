import Foundation
@testable import PureYAML
import Testing

@Suite("Performance Phases")
struct PerformancePhaseTests {
    @Test("Profiles parser phases for representative slow corpus seeds")
    func test_profilesParserPhasesForRepresentativeSeeds() throws {
        guard ProcessInfo.processInfo.environment["PUREYAML_RUN_PHASE_PROFILER"] == "1" else {
            return
        }

        let measurements = try PerformancePhaseSeed.all.map(profile)
        let slowestLazyParse = measurements.map(\.lazyParse.seconds).max() ?? 0
        let slowestMaterializedPipeline = measurements.map(\.materializedPipelineSeconds).max() ?? 0
        let report: [String: Any] = [
            "summary": [
                "seeds": measurements.count,
                "slowestLazyParseSeconds": slowestLazyParse,
                "slowestMaterializedPipelineSeconds": slowestMaterializedPipeline,
            ],
            "measurements": measurements.map(\.object),
        ]
        let artifactURL = try performancePhaseArtifactURL()
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: artifactURL)

        print("PureYAML phase profiler seeds: \(measurements.count)")
        for measurement in measurements {
            print(measurement.summaryLine)
        }
        print("Report: \(artifactURL.path)")
    }
}

private struct PerformancePhaseSeed {
    var id: String
    var localPath: String
    var iterations: Int

    static let all = [
        PerformancePhaseSeed(
            id: "cert-manager-crd",
            localPath: "cert-manager-certificate-crd.yaml",
            iterations: 20,
        ),
        PerformancePhaseSeed(
            id: "stripe-yaml",
            localPath: "api-guru-stripe-openapi.yaml",
            iterations: 2,
        ),
        PerformancePhaseSeed(
            id: "zoom-yaml",
            localPath: "api-guru-zoom-openapi.yaml",
            iterations: 2,
        ),
    ]
}

private struct PhaseTiming {
    var seconds: TimeInterval
    var units: Int

    var object: [String: Any] {
        [
            "seconds": seconds,
            "units": units,
        ]
    }
}

private struct PhaseMeasurement {
    var seed: PerformancePhaseSeed
    var bytes: Int
    var scanner: PhaseTiming
    var eventParser: PhaseTiming
    var composer: PhaseTiming
    var lazyParse: PhaseTiming
    var validation: PhaseTiming
    var dumping: PhaseTiming

    var materializedPipelineSeconds: TimeInterval {
        scanner.seconds + eventParser.seconds + composer.seconds
    }

    var object: [String: Any] {
        [
            "id": seed.id,
            "localPath": seed.localPath,
            "bytes": bytes,
            "iterations": seed.iterations,
            "scanner": scanner.object,
            "eventParser": eventParser.object,
            "composer": composer.object,
            "lazyParse": lazyParse.object,
            "validation": validation.object,
            "dumping": dumping.object,
            "materializedPipelineSeconds": materializedPipelineSeconds,
        ]
    }

    var summaryLine: String {
        [
            seed.id,
            "bytes=\(bytes)",
            "iter=\(seed.iterations)",
            "scan=\(format(scanner.seconds))s",
            "events=\(format(eventParser.seconds))s",
            "compose=\(format(composer.seconds))s",
            "lazy=\(format(lazyParse.seconds))s",
            "validate=\(format(validation.seconds))s",
            "dump=\(format(dumping.seconds))s",
        ].joined(separator: " ")
    }
}

private struct WarmedPerformanceInputs {
    var tokens: [PureYAML.Parsing.Token]
    var events: [PureYAML.Parsing.Event]
    var documents: [PureYAML.Stream.Document]
}

private func profile(_ seed: PerformancePhaseSeed) throws -> PhaseMeasurement {
    let yaml = try String(contentsOf: fixtureURL(for: seed), encoding: .utf8)
    let parser = PureYAML.Parsing.Parser()
    let warmed = try warmup(yaml: yaml, parser: parser)
    let scanner = try timeScanner(yaml: yaml, iterations: seed.iterations)
    let eventParser = try timeEventParser(tokens: warmed.tokens, parser: parser, iterations: seed.iterations)
    let composer = try timeComposer(events: warmed.events, parser: parser, iterations: seed.iterations)
    let lazyParse = try timeLazyParse(yaml: yaml, iterations: seed.iterations)
    let validation = timeValidation(documents: warmed.documents, iterations: seed.iterations)
    let dumping = timeDumping(documents: warmed.documents, iterations: seed.iterations)

    return PhaseMeasurement(
        seed: seed,
        bytes: yaml.utf8.count,
        scanner: .init(seconds: scanner.seconds, units: scanner.value),
        eventParser: .init(seconds: eventParser.seconds, units: eventParser.value),
        composer: .init(seconds: composer.seconds, units: composer.value),
        lazyParse: .init(seconds: lazyParse.seconds, units: lazyParse.value),
        validation: .init(seconds: validation.seconds, units: validation.value),
        dumping: .init(seconds: dumping.seconds, units: dumping.value),
    )
}

private func warmup(
    yaml: String,
    parser: PureYAML.Parsing.Parser,
) throws -> WarmedPerformanceInputs {
    let tokens = try PureYAML.Parsing.Scanner().scan(yaml)
    var eventParser = PureYAML.Parsing.TokenEventParser(tokens: tokens, scalarParser: parser)
    let events = try eventParser.parse()
    var composer = PureYAML.Parsing.EventComposer(events: events, scalarParser: parser)
    let documents = try composer.composeStream()
    _ = PureYAML.Validation.Validator().collect(documents)
    _ = PureYAML.dump(documents)
    _ = try PureYAML.parseStream(yaml)
    return WarmedPerformanceInputs(tokens: tokens, events: events, documents: documents)
}

private func timeScanner(
    yaml: String,
    iterations: Int,
) throws -> (seconds: TimeInterval, value: Int) {
    try timed {
        var units = 0
        for _ in 0 ..< iterations {
            units += try PureYAML.Parsing.Scanner().scan(yaml).count
        }
        return units
    }
}

private func timeEventParser(
    tokens: [PureYAML.Parsing.Token],
    parser: PureYAML.Parsing.Parser,
    iterations: Int,
) throws -> (seconds: TimeInterval, value: Int) {
    try timed {
        var units = 0
        for _ in 0 ..< iterations {
            var eventParser = PureYAML.Parsing.TokenEventParser(tokens: tokens, scalarParser: parser)
            units += try eventParser.parse().count
        }
        return units
    }
}

private func timeComposer(
    events: [PureYAML.Parsing.Event],
    parser: PureYAML.Parsing.Parser,
    iterations: Int,
) throws -> (seconds: TimeInterval, value: Int) {
    try timed {
        var units = 0
        for _ in 0 ..< iterations {
            var composer = PureYAML.Parsing.EventComposer(events: events, scalarParser: parser)
            units += try composer.composeStream().count
        }
        return units
    }
}

private func timeLazyParse(
    yaml: String,
    iterations: Int,
) throws -> (seconds: TimeInterval, value: Int) {
    try timed {
        var units = 0
        for _ in 0 ..< iterations {
            units += try PureYAML.parseStream(yaml).count
        }
        return units
    }
}

private func timeValidation(
    documents: [PureYAML.Stream.Document],
    iterations: Int,
) -> (seconds: TimeInterval, value: Int) {
    timed {
        var units = 0
        for _ in 0 ..< iterations {
            units += PureYAML.Validation.Validator().collect(documents).issues.count
        }
        return units
    }
}

private func timeDumping(
    documents: [PureYAML.Stream.Document],
    iterations: Int,
) -> (seconds: TimeInterval, value: Int) {
    timed {
        var units = 0
        for _ in 0 ..< iterations {
            units += PureYAML.dump(documents).utf8.count
        }
        return units
    }
}

private func fixtureURL(for seed: PerformancePhaseSeed) throws -> URL {
    try #require(Bundle.module.url(
        forResource: seed.resourceName,
        withExtension: seed.resourceExtension,
        subdirectory: "Fixtures/real-yaml",
    ))
}

private func performancePhaseArtifactURL() throws -> URL {
    if let path = ProcessInfo.processInfo.environment["PUREYAML_PHASE_PROFILER_ARTIFACT"] {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        return url
    }

    let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build")
        .appendingPathComponent("pureyaml-artifacts")
        .appendingPathComponent("performance")
        .appendingPathComponent("phase-profile.json")
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true,
    )
    return url
}

private func timed(_ body: () throws -> Int) rethrows -> (seconds: TimeInterval, value: Int) {
    let start = DispatchTime.now().uptimeNanoseconds
    let value = try body()
    let end = DispatchTime.now().uptimeNanoseconds
    return (Double(end - start) / 1_000_000_000, value)
}

private func format(_ value: Double) -> String {
    String(format: "%.3f", value)
}

private extension PerformancePhaseSeed {
    var resourceName: String {
        guard let dotIndex = localPath.lastIndex(of: ".") else {
            return localPath
        }
        return String(localPath[..<dotIndex])
    }

    var resourceExtension: String {
        guard let dotIndex = localPath.lastIndex(of: ".") else {
            return ""
        }
        return String(localPath[localPath.index(after: dotIndex)...])
    }
}
