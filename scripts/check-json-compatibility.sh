#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.build/json-compatibility"
ARTIFACT_DIR="$ROOT_DIR/.build/pureyaml-artifacts/json"

mkdir -p "$WORK_DIR/Sources/JSONCompatibility" "$ARTIFACT_DIR"

cat > "$WORK_DIR/Package.swift" <<EOF
// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PureYAMLJSONCompatibility",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: "$ROOT_DIR"),
    ],
    targets: [
        .executableTarget(
            name: "JSONCompatibility",
            dependencies: [
                "PureYAML",
            ],
        ),
    ],
)
EOF

cat > "$WORK_DIR/Sources/JSONCompatibility/main.swift" <<'EOF'
import Foundation
import PureYAML

struct ValidCase {
    var name: String
    var json: String
}

struct InvalidCase {
    var name: String
    var json: String
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: JSONCompatibility <artifact-json>\n".utf8))
    Foundation.exit(64)
}

let validCases = [
    ValidCase(
        name: "compact object",
        json: #"{"openapi":"3.0.0","info":{"title":"JSON API","version":"1"},"paths":{},"enabled":true,"count":3}"#,
    ),
    ValidCase(name: "array root", json: #"[{"a":1},{"b":null},{"items":[true,false]}]"#),
    ValidCase(name: "string root", json: #""hello""#),
    ValidCase(name: "integer root", json: #"123"#),
    ValidCase(name: "boolean root", json: #"true"#),
    ValidCase(name: "null root", json: #"null"#),
    ValidCase(
        name: "string escapes",
        json: #"{"quote":"\"","slash":"\\","solidus":"\/","backspace":"\b","formfeed":"\f","newline":"line\nnext","return":"a\rb","tab":"a\tb"}"#,
    ),
    ValidCase(name: "unicode escapes", json: #"{"bmp":"\u263A","surrogate":"\uD834\uDD1E"}"#),
    ValidCase(name: "number forms", json: #"{"zero":0,"negative":-3,"fraction":1.25,"small":1e-6,"big":6.02E23}"#),
    ValidCase(
        name: "insignificant whitespace",
        json: """
        {
          "items" : [
            { "url" : "https://api.example.com/a:b" },
            { "window" : "10:30" }
          ]
        }
        """,
    ),
    ValidCase(name: "empty containers", json: #"{"object":{},"array":[]}"#),
]

let invalidCases = [
    InvalidCase(name: "missing value", json: #"{"a":}"#),
    InvalidCase(name: "double comma", json: #"[1,,2]"#),
    InvalidCase(name: "unquoted key", json: #"{a:1}"#),
    InvalidCase(name: "comment", json: #"{"a":1 // no comments in JSON"#),
    InvalidCase(name: "single quoted string", json: #"{'a':1}"#),
]

let validResults = validCases.map { testCase -> [String: Any] in
    do {
        let json = try JSONOracle.decode(testCase.json)
        let yaml = try JSONOracle(pureYAML: PureYAML.parse(testCase.json))
        return [
            "name": testCase.name,
            "acceptedByJSONOracle": true,
            "acceptedByPureYAML": true,
            "structurallyEqual": yaml == json,
        ]
    } catch {
        return [
            "name": testCase.name,
            "acceptedByJSONOracle": false,
            "acceptedByPureYAML": false,
            "structurallyEqual": false,
            "error": String(describing: error),
        ]
    }
}

let invalidResults = invalidCases.map { testCase -> [String: Any] in
    do {
        _ = try JSONOracle.decode(testCase.json)
        return [
            "name": testCase.name,
            "rejectedByJSONOracle": false,
        ]
    } catch {
        return [
            "name": testCase.name,
            "rejectedByJSONOracle": true,
        ]
    }
}

let validFailures = validResults.filter { result in
    result["structurallyEqual"] as? Bool != true
}
let invalidFailures = invalidResults.filter { result in
    result["rejectedByJSONOracle"] as? Bool != true
}
let report: [String: Any] = [
    "summary": [
        "validCases": validCases.count,
        "validCasesStructurallyEqual": validCases.count - validFailures.count,
        "invalidCases": invalidCases.count,
        "invalidCasesRejectedByOracle": invalidCases.count - invalidFailures.count,
        "failures": validFailures.count + invalidFailures.count,
    ],
    "valid": validResults,
    "invalid": invalidResults,
]

let artifactURL = URL(fileURLWithPath: arguments[1])
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try data.write(to: artifactURL)

print("JSON compatibility valid cases: \(validCases.count)")
print("JSON compatibility structurally equal: \(validCases.count - validFailures.count)")
print("JSON invalid oracle rejections: \(invalidCases.count - invalidFailures.count)")
print("Report: \(artifactURL.path)")

if !validFailures.isEmpty || !invalidFailures.isEmpty {
    Foundation.exit(1)
}

enum JSONOracle: Equatable, Decodable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONOracle])
    case object([String: JSONOracle])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONOracle].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONOracle].self))
        }
    }

    init(pureYAML value: PureYAML.Model.Value) throws {
        switch value {
        case .null:
            self = .null
        case let .bool(value):
            self = .bool(value)
        case let .int(value):
            self = .int(value)
        case let .double(value):
            self = .double(value)
        case let .string(value):
            self = .string(value)
        case let .sequence(values):
            self = .array(try values.map(JSONOracle.init(pureYAML:)))
        case let .mapping(mapping):
            self = .object(try mapping.pairs.reduce(into: [:]) { result, pair in
                guard case let .string(key) = pair.keyNode.value else {
                    throw JSONOracleFailure.nonStringKey
                }
                result[key] = try JSONOracle(pureYAML: pair.value)
            })
        }
    }

    static func decode(_ json: String) throws -> JSONOracle {
        try JSONDecoder().decode(JSONOracle.self, from: Data(json.utf8))
    }
}

enum JSONOracleFailure: Error {
    case nonStringKey
}
EOF

swift run \
    --package-path "$WORK_DIR" \
    JSONCompatibility \
    "$ARTIFACT_DIR/json-compatibility.json"
