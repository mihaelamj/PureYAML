import Foundation
@testable import PureYAML
import Testing

@Suite("JSON Compatibility")
struct JSONCompatibilityTests {
    @Test(
        "Parses valid JSON as YAML 1.2",
        arguments: JSONCompatibilityFixtures.validDocuments,
    )
    func test_parsesValidJSONAsYAML(testCase: JSONCompatibilityFixtures.ValidDocument) throws {
        let json = try JSONOracle.decode(testCase.json)
        let yaml = try JSONOracle(pureYAML: PureYAML.parse(testCase.json))

        #expect(yaml == json)
    }

    @Test(
        "JSON oracle rejects invalid JSON fixtures",
        arguments: JSONCompatibilityFixtures.invalidDocuments,
    )
    func test_jsonOracleRejectsInvalidJSON(testCase: JSONCompatibilityFixtures.InvalidDocument) {
        do {
            _ = try JSONOracle.decode(testCase.json)
            recordIssue("expected JSON oracle to reject \(testCase.name)")
        } catch {}
    }
}

enum JSONCompatibilityFixtures {
    struct ValidDocument: CustomTestStringConvertible {
        var name: String
        var json: String

        var testDescription: String {
            name
        }
    }

    struct InvalidDocument: CustomTestStringConvertible {
        var name: String
        var json: String

        var testDescription: String {
            name
        }
    }

    static let validDocuments = [
        ValidDocument(
            name: "compact object",
            json: #"{"openapi":"3.0.0","info":{"title":"JSON API","version":"1"},"paths":{},"enabled":true,"count":3}"#,
        ),
        ValidDocument(
            name: "array root",
            json: #"[{"a":1},{"b":null},{"items":[true,false]}]"#,
        ),
        ValidDocument(
            name: "scalar roots",
            json: #""hello""#,
        ),
        ValidDocument(
            name: "integer root",
            json: #"123"#,
        ),
        ValidDocument(
            name: "boolean root",
            json: #"true"#,
        ),
        ValidDocument(
            name: "null root",
            json: #"null"#,
        ),
        ValidDocument(
            name: "string escapes",
            json: #"{"quote":"\"","slash":"\\","solidus":"\/","backspace":"\b","formfeed":"\f","newline":"line\nnext","return":"a\rb","tab":"a\tb"}"#,
        ),
        ValidDocument(
            name: "unicode escapes",
            json: #"{"bmp":"\u263A","surrogate":"\uD834\uDD1E"}"#,
        ),
        ValidDocument(
            name: "number forms",
            json: #"{"zero":0,"negative":-3,"fraction":1.25,"small":1e-6,"big":6.02E23}"#,
        ),
        ValidDocument(
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
        ValidDocument(
            name: "empty containers",
            json: #"{"object":{},"array":[]}"#,
        ),
    ]

    static let invalidDocuments = [
        InvalidDocument(name: "missing value", json: #"{"a":}"#),
        InvalidDocument(name: "double comma", json: #"[1,,2]"#),
        InvalidDocument(name: "unquoted key", json: #"{a:1}"#),
        InvalidDocument(name: "comment", json: #"{"a":1 // no comments in JSON"#),
        InvalidDocument(name: "single quoted string", json: #"{'a':1}"#),
    ]
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
            self = try .object(container.decode([String: JSONOracle].self))
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
            self = try .array(values.map(JSONOracle.init(pureYAML:)))
        case let .mapping(mapping):
            self = try .object(mapping.pairs.reduce(into: [:]) { result, pair in
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
