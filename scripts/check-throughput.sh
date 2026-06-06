#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.build/yams-throughput"
ARTIFACT_DIR="$ROOT_DIR/.build/pureyaml-artifacts/performance"

mkdir -p "$WORK_DIR/Sources/YamsThroughput" "$ARTIFACT_DIR"

cat > "$WORK_DIR/Package.swift" <<EOF
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PureYAMLYamsThroughput",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "$ROOT_DIR"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "YamsThroughput",
            dependencies: [
                "PureYAML",
                .product(name: "Yams", package: "Yams"),
            ],
        ),
    ],
)
EOF

cat > "$WORK_DIR/Sources/YamsThroughput/main.swift" <<'EOF'
import Foundation
import PureYAML
import Yams

struct Seed {
    var id: String
    var localPath: String
    var iterations: Int
}

struct Measurement {
    var seed: Seed
    var bytes: Int
    var pureSeconds: TimeInterval
    var yamsSeconds: TimeInterval
    var pureDocuments: Int
    var yamsDocuments: Int

    var pureMegabytesPerSecond: Double {
        Double(bytes * seed.iterations) / pureSeconds / 1_000_000
    }

    var yamsMegabytesPerSecond: Double {
        Double(bytes * seed.iterations) / yamsSeconds / 1_000_000
    }

    var ratio: Double {
        pureMegabytesPerSecond / yamsMegabytesPerSecond
    }

    var object: [String: Any] {
        [
            "id": seed.id,
            "localPath": seed.localPath,
            "bytes": bytes,
            "iterations": seed.iterations,
            "pureyaml": [
                "seconds": pureSeconds,
                "megabytesPerSecond": pureMegabytesPerSecond,
                "documents": pureDocuments,
            ],
            "yams": [
                "seconds": yamsSeconds,
                "megabytesPerSecond": yamsMegabytesPerSecond,
                "documents": yamsDocuments,
            ],
            "pureyamlToYamsRatio": ratio,
        ]
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: YamsThroughput <repo-root> <artifact-json>\n".utf8))
    Foundation.exit(64)
}

let rootURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let artifactURL = URL(fileURLWithPath: arguments[2])
let fixtureURL = rootURL
    .appendingPathComponent("Tests")
    .appendingPathComponent("Fixtures")
    .appendingPathComponent("real-yaml")

let seeds = [
    Seed(id: "petstore", localPath: "openapi-petstore.yaml", iterations: 100),
    Seed(id: "prometheus", localPath: "prometheus-conf-good.yml", iterations: 60),
    Seed(id: "cert-manager-crd", localPath: "cert-manager-certificate-crd.yaml", iterations: 20),
    Seed(id: "stripe-yaml", localPath: "api-guru-stripe-openapi.yaml", iterations: 2),
    Seed(id: "zoom-yaml", localPath: "api-guru-zoom-openapi.yaml", iterations: 2),
]

let measurements = try seeds.map { seed in
    let url = fixtureURL.appendingPathComponent(seed.localPath)
    let yaml = try String(contentsOf: url, encoding: .utf8)

    _ = try PureYAML.parseStream(yaml)
    _ = try Array(Yams.load_all(yaml: yaml))

    let pure = try timed {
        var documents = 0
        for _ in 0..<seed.iterations {
            documents += try PureYAML.parseStream(yaml).count
        }
        return documents
    }
    let yams = try timed {
        var documents = 0
        for _ in 0..<seed.iterations {
            documents += try Array(Yams.load_all(yaml: yaml)).count
        }
        return documents
    }
    return Measurement(
        seed: seed,
        bytes: yaml.utf8.count,
        pureSeconds: pure.seconds,
        yamsSeconds: yams.seconds,
        pureDocuments: pure.value,
        yamsDocuments: yams.value,
    )
}

let report: [String: Any] = [
    "summary": [
        "seeds": measurements.count,
        "pureyamlFasterOrEqual": measurements.filter { $0.ratio >= 1 }.count,
        "pureyamlSlower": measurements.filter { $0.ratio < 1 }.count,
        "minimumRatio": measurements.map(\.ratio).min() ?? 0,
    ],
    "measurements": measurements.map(\.object),
]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: artifactURL)

print("Yams throughput corpus seeds: \(measurements.count)")
for measurement in measurements {
    print([
        measurement.seed.id,
        "bytes=\(measurement.bytes)",
        "iter=\(measurement.seed.iterations)",
        "pure=\(format(measurement.pureMegabytesPerSecond))MB/s",
        "yams=\(format(measurement.yamsMegabytesPerSecond))MB/s",
        "ratio=\(format(measurement.ratio))",
    ].joined(separator: " "))
}
print("Report: \(artifactURL.path)")

func timed(_ body: () throws -> Int) rethrows -> (seconds: TimeInterval, value: Int) {
    let start = DispatchTime.now().uptimeNanoseconds
    let value = try body()
    let end = DispatchTime.now().uptimeNanoseconds
    return (Double(end - start) / 1_000_000_000, value)
}

func format(_ value: Double) -> String {
    String(format: "%.2f", value)
}
EOF

swift run \
    -c release \
    --package-path "$WORK_DIR" \
    YamsThroughput \
    "$ROOT_DIR" \
    "$ARTIFACT_DIR/yams-throughput.json"
