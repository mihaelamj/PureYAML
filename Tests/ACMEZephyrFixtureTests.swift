import Foundation
@testable import PureYAML
import Testing

@Suite("ACME Fixtures")
struct ACMEZephyrFixtureTests {
    @Test("Parses Stitcher-style ACME Zephyr source files")
    func test_parsesStitcherStyleACMEZephyrSourceFiles() throws {
        let spec = try loadFixture("spec.yml", subdirectory: "Fixtures/acme/zephyr-data")
        let activeFeature = try loadFixture(
            "activeZorplexFeature.yml",
            subdirectory: "Fixtures/acme/zephyr-data/schemas",
        )
        let featureEnum = try loadFixture("zorplexFeature.yml", subdirectory: "Fixtures/acme/zephyr-data/schemas")

        let specRoot = try requireMapping(PureYAML.parse(spec))
        #expect(specRoot["openapi"] == .string("3.0.3"))

        let schemas = expectMapping(expectMapping(specRoot["components"])?["schemas"])
        #expect(expectMapping(schemas?["ActiveZorplexFeature"])?["$ref"] == .string("./schemas/activeZorplexFeature.yml"))
        #expect(expectMapping(schemas?["ZorplexFeature"])?["$ref"] == .string("./schemas/zorplexFeature.yml"))

        let activeRoot = try requireMapping(PureYAML.parse(activeFeature))
        #expect(activeRoot["type"] == .string("object"))
        #expect(requireSequence(activeRoot["required"])?.contains(.string("createdBy")) == true)
        let properties = expectMapping(activeRoot["properties"])
        #expect(expectMapping(properties?["feature"])?["$ref"] == .string("./zorplexFeature.yml"))
        #expect(expectMapping(properties?["deletedAt"])?["nullable"] == .bool(true))

        let featureRoot = try requireMapping(PureYAML.parse(featureEnum))
        #expect(featureRoot["type"] == .string("string"))
        #expect(requireSequence(featureRoot["enum"])?.contains(.string("QUASAR_MATRIX_V2")) == true)
    }

    @Test("Parses bundled ACME Zephyr output")
    func test_parsesBundledACMEZephyrOutput() throws {
        let bundled = try loadFixture("bundled.yml", subdirectory: "Fixtures/acme/zephyr-data")
        let root = try requireMapping(PureYAML.parse(bundled))

        #expect(root["openapi"] == .string("3.0.3"))
        let paths = expectMapping(root["paths"])
        let operation = expectMapping(expectMapping(paths?["/activeZorplexFeatures"])?["get"])
        #expect(operation?["operationId"] == .string("getActiveZorplexFeatures"))

        let components = expectMapping(root["components"])
        let schemas = expectMapping(components?["schemas"])
        let active = expectMapping(schemas?["ActiveZorplexFeature"])
        let properties = expectMapping(active?["properties"])
        let feature = expectMapping(properties?["feature"])
        #expect(requireSequence(feature?["enum"])?.contains(.string("BLARF_OPTIMIZATION")) == true)
        #expect(expectMapping(properties?["deletedAt"])?["nullable"] == .bool(true))
    }

    @Test("Parses renamed Birch-style ACME catalog representative files")
    func test_parsesRenamedBirchStyleACMECatalogRepresentativeFiles() throws {
        let eventSpec = try loadFixture("spec.yml", subdirectory: "Fixtures/acme/birch-catalog/ui-event")
        let originatorSpec = try loadFixture("spec.yml", subdirectory: "Fixtures/acme/birch-catalog/originator")
        let originatorOffer = try loadFixture("offer.yml", subdirectory: "Fixtures/acme/birch-catalog/originator/schemas")
        let apiError = try loadFixture("apiError.yml", subdirectory: "Fixtures/acme/birch-catalog/core/schemas")

        let eventRoot = try requireMapping(PureYAML.parse(eventSpec))
        #expect(eventRoot["openapi"] == .string("3.0.3"))
        let eventSecurity = expectMapping(expectMapping(eventRoot["components"])?["securitySchemes"])
        let oauth = expectMapping(eventSecurity?["oauth"])
        let scopes = expectMapping(expectMapping(expectMapping(oauth?["flows"])?["clientCredentials"])?["scopes"])
        #expect(scopes?["ui-event:write"] == .string("Allows recording UI events"))

        let eventSchemas = expectMapping(expectMapping(eventRoot["components"])?["schemas"])
        #expect(expectMapping(eventSchemas?["ApiError"])?["$ref"] == .string("../core/schemas/apiError.yml"))
        #expect(expectMapping(eventSchemas?["SessionInit"])?["$ref"] == .string("./schemas/sessionInit.yml"))
        let offerDisplays = expectMapping(expectMapping(eventRoot["paths"])?["/offerDisplays"])
        let createOperation = expectMapping(offerDisplays?["post"])
        #expect(expectMapping(createOperation?["requestBody"])?["$ref"] == .string("./request-bodies/offerDisplay.yml"))

        let originatorRoot = try requireMapping(PureYAML.parse(originatorSpec))
        let originatorSchemas = expectMapping(expectMapping(originatorRoot["components"])?["schemas"])
        #expect(expectMapping(originatorSchemas?["ApiError"])?["$ref"] == .string("../core/schemas/apiError.yml"))
        #expect(expectMapping(originatorSchemas?["CreditCardOfferRecord"])?["$ref"] == .string("./schemas/creditCardOfferRecord.yml"))
        let originatorSecurity = expectMapping(expectMapping(originatorRoot["components"])?["securitySchemes"])
        let originatorOAuth = expectMapping(originatorSecurity?["oauth"])
        let originatorClientCredentials = expectMapping(expectMapping(originatorOAuth?["flows"])?["clientCredentials"])
        let originatorScopes = expectMapping(originatorClientCredentials?["scopes"])
        #expect(originatorScopes?["originator:admin:write"] == .string("Allows write access to all admin endpoints in originator"))

        let offerRoot = try requireMapping(PureYAML.parse(originatorOffer))
        let offerProperties = expectMapping(offerRoot["properties"])
        #expect(expectMapping(offerProperties?["partner"])?["$ref"] == .string("./demandPartner.yml"))
        #expect(expectMapping(offerProperties?["productType"])?["$ref"] == .string("../../core/schemas/productType.yml"))
        #expect(expectMapping(offerProperties?["productSubType"])?["$ref"] == .string("../../lead/schemas/productSubType.yml"))

        let errorRoot = try requireMapping(PureYAML.parse(apiError))
        let errorProperties = expectMapping(errorRoot["properties"])
        #expect(expectMapping(errorProperties?["details"])?["$ref"] == .string("./apiErrorDetails.yml"))
        #expect(expectMapping(errorProperties?["message"])?["readOnly"] == .bool(true))
    }

    @Test("Parses all renamed Birch-style ACME catalog YAML files")
    func test_parsesAllRenamedBirchStyleACMECatalogYAMLFiles() throws {
        let rootURL = try #require(Bundle.module.url(
            forResource: "birch-catalog",
            withExtension: nil,
            subdirectory: "Fixtures/acme",
        ))
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: rootURL.path)
            .filter { $0.hasSuffix(".yml") || $0.hasSuffix(".yaml") }
            .sorted()
        #expect(files.count == 594)

        for file in files {
            let url = rootURL.appendingPathComponent(file)
            let source = try String(contentsOf: url, encoding: .utf8)
            _ = try PureYAML.parse(source)
        }
    }

    private func loadFixture(_ name: String, subdirectory: String) throws -> String {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: subdirectory))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func requireMapping(_ value: PureYAML.Model.Value) throws -> PureYAML.Model.Mapping {
        guard case let .mapping(mapping) = value else {
            recordIssue("expected mapping")
            return .init()
        }
        return mapping
    }

    private func expectMapping(_ value: PureYAML.Model.Value?) -> PureYAML.Model.Mapping? {
        guard case let .mapping(mapping)? = value else {
            recordIssue("expected mapping")
            return nil
        }
        return mapping
    }

    private func requireSequence(_ value: PureYAML.Model.Value?) -> [PureYAML.Model.Value]? {
        guard case let .sequence(sequence)? = value else {
            recordIssue("expected sequence")
            return nil
        }
        return sequence
    }
}
