#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.build/yams-differential"
ARTIFACT_DIR="$ROOT_DIR/.build/pureyaml-artifacts/differential"

mkdir -p "$WORK_DIR/Sources/YamsDifferential" "$ARTIFACT_DIR"

cat > "$WORK_DIR/Package.swift" <<EOF
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PureYAMLYamsDifferential",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "$ROOT_DIR"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "YamsDifferential",
            dependencies: [
                "PureYAML",
                .product(name: "Yams", package: "Yams"),
            ],
        ),
    ],
)
EOF

cat > "$WORK_DIR/Sources/YamsDifferential/main.swift" <<'EOF'
import Foundation
import PureYAML
import Yams

struct Seed {
    var id: String
    var localPath: String
    var category: String
    var tier: String
    var repository: String
    var commit: String
    var sourcePath: String
    var expectedDifferential: String
}

struct Comparison {
    var seed: Seed
    var pureSuccess: Bool
    var pureDocumentCount: Int?
    var pureError: String?
    var yamsSuccess: Bool
    var yamsDocumentCount: Int?
    var yamsError: String?

    var agrees: Bool {
        if seed.expectedDifferential == "yamsEmptyStreamZeroDocuments" {
            return pureSuccess && yamsSuccess && pureDocumentCount == 1 && yamsDocumentCount == 0
        }
        return pureSuccess == yamsSuccess && pureDocumentCount == yamsDocumentCount
    }

    var object: [String: Any] {
        [
            "id": seed.id,
            "localPath": seed.localPath,
            "category": seed.category,
            "tier": seed.tier,
            "repository": seed.repository,
            "commit": seed.commit,
            "sourcePath": seed.sourcePath,
            "expectedDifferential": seed.expectedDifferential,
            "agrees": agrees,
            "pureyaml": [
                "success": pureSuccess,
                "documentCount": pureDocumentCount as Any,
                "error": pureError as Any,
            ],
            "yams": [
                "success": yamsSuccess,
                "documentCount": yamsDocumentCount as Any,
                "error": yamsError as Any,
            ],
        ]
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: YamsDifferential <repo-root> <artifact-json>\n".utf8))
    Foundation.exit(64)
}

let rootURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let artifactURL = URL(fileURLWithPath: arguments[2])
let manifestURL = rootURL
    .appendingPathComponent("Tests")
    .appendingPathComponent("Fixtures")
    .appendingPathComponent("real-yaml-corpus.yaml")

let manifest = try PureYAML.parse(String(contentsOf: manifestURL, encoding: .utf8))
let seeds = try loadSeeds(from: manifest)

var comparisons: [Comparison] = []
for seed in seeds {
    let sourceURL = rootURL
        .appendingPathComponent("Tests")
        .appendingPathComponent("Fixtures")
        .appendingPathComponent(seed.localPath)
    let yaml = try String(contentsOf: sourceURL, encoding: .utf8)

    let pure = parseWithPureYAML(yaml)
    let yams = parseWithYams(yaml)
    comparisons.append(Comparison(
        seed: seed,
        pureSuccess: pure.success,
        pureDocumentCount: pure.documentCount,
        pureError: pure.error,
        yamsSuccess: yams.success,
        yamsDocumentCount: yams.documentCount,
        yamsError: yams.error,
    ))
}

let disagreements = comparisons.filter { !$0.agrees }
let report: [String: Any] = [
    "summary": [
        "seeds": comparisons.count,
        "agreements": comparisons.count - disagreements.count,
        "disagreements": disagreements.count,
    ],
    "comparisons": comparisons.map(\.object),
]

let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: artifactURL)

print("Yams differential corpus seeds: \(comparisons.count)")
print("Agreements: \(comparisons.count - disagreements.count)")
print("Disagreements: \(disagreements.count)")
print("Report: \(artifactURL.path)")

if !disagreements.isEmpty {
    for comparison in disagreements {
        print("DISAGREE \(comparison.seed.id)")
        print("  PureYAML: \(comparison.pureSuccess) documents=\(comparison.pureDocumentCount.map(String.init) ?? "nil") error=\(comparison.pureError ?? "nil")")
        print("  Yams:     \(comparison.yamsSuccess) documents=\(comparison.yamsDocumentCount.map(String.init) ?? "nil") error=\(comparison.yamsError ?? "nil")")
    }
    Foundation.exit(1)
}

func parseWithPureYAML(_ yaml: String) -> (success: Bool, documentCount: Int?, error: String?) {
    do {
        let documents = try PureYAML.parseStream(yaml)
        return (true, documents.count, nil)
    } catch {
        return (false, nil, String(describing: error))
    }
}

func parseWithYams(_ yaml: String) -> (success: Bool, documentCount: Int?, error: String?) {
    do {
        let documents = try Yams.load_all(yaml: yaml)
        return (true, Array(documents).count, nil)
    } catch {
        return (false, nil, String(describing: error))
    }
}

func loadSeeds(from value: PureYAML.Model.Value) throws -> [Seed] {
    guard case let .mapping(root) = value,
          case let .sequence(seedValues)? = root["seeds"]
    else {
        throw Failure("real-yaml-corpus.yaml must contain a seeds sequence")
    }

    return try seedValues.map { value in
        guard case let .mapping(mapping) = value else {
            throw Failure("seed entry must be a mapping")
        }
        return Seed(
            id: try mapping.requiredString("id"),
            localPath: try mapping.requiredString("localPath"),
            category: try mapping.requiredString("category"),
            tier: try mapping.requiredString("tier"),
            repository: try mapping.requiredString("repository"),
            commit: try mapping.requiredString("commit"),
            sourcePath: try mapping.requiredString("sourcePath"),
            expectedDifferential: try mapping.requiredString("expectedDifferential"),
        )
    }
}

struct Failure: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}

extension PureYAML.Model.Mapping {
    func requiredString(_ key: String) throws -> String {
        guard case let .string(value)? = self[key] else {
            throw Failure("seed entry missing string key \(key)")
        }
        return value
    }
}
EOF

swift run \
    --package-path "$WORK_DIR" \
    YamsDifferential \
    "$ROOT_DIR" \
    "$ARTIFACT_DIR/yams-comparison.json"
