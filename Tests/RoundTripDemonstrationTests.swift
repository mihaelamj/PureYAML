import Foundation
@testable import PureYAML
import Testing

/// End-to-end demonstrations of the four supported conversions:
/// parsing YAML, parsing JSON, generating YAML, and generating JSON.
///
/// JSON parsing is handled by PureYAML directly because YAML 1.2 is a strict
/// superset of JSON. JSON generation is delegated to Foundation, which is the
/// correct tool for guaranteed-strict JSON output.
@Suite("Round-Trip Demonstration")
struct RoundTripDemonstrationTests {
    struct Config: Codable, Equatable {
        var name: String
        var port: Int
        var enabled: Bool
        var hosts: [String]
    }

    static let config = Config(
        name: "server",
        port: 8080,
        enabled: true,
        hosts: ["a.example.com", "b.example.com"],
    )

    // MARK: Parsing YAML

    @Test("Parses YAML into a typed value")
    func test_parsesYAML() throws {
        let yaml = """
        name: server
        port: 8080
        enabled: true
        hosts:
          - a.example.com
          - b.example.com
        """

        let decoded = try PureYAML.decode(Config.self, from: yaml)

        #expect(decoded == Self.config)
    }

    // MARK: Parsing JSON

    @Test("Parses JSON into the same typed value, since YAML is a JSON superset")
    func test_parsesJSON() throws {
        let json = #"""
        {"name": "server", "port": 8080, "enabled": true, "hosts": ["a.example.com", "b.example.com"]}
        """#

        let decoded = try PureYAML.decode(Config.self, from: json)

        #expect(decoded == Self.config)
    }

    // MARK: Generating YAML

    @Test("Generates YAML from a typed value")
    func test_generatesYAML() throws {
        let yaml = try PureYAML.encodeToYAML(Self.config)

        #expect(yaml == """
        name: "server"
        port: 8080
        enabled: true
        hosts:
          - "a.example.com"
          - "b.example.com"

        """)

        // The generated YAML round-trips back into the same value.
        #expect(try PureYAML.decode(Config.self, from: yaml) == Self.config)
    }

    // MARK: Generating JSON (Foundation)

    @Test("Generates strict JSON from a typed value using Foundation")
    func test_generatesJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(Self.config)
        let json = try #require(String(bytes: data, encoding: .utf8))

        #expect(json == #"{"enabled":true,"hosts":["a.example.com","b.example.com"],"name":"server","port":8080}"#)

        // The Foundation-generated JSON parses back through PureYAML to the same value.
        #expect(try PureYAML.decode(Config.self, from: json) == Self.config)
    }
}
