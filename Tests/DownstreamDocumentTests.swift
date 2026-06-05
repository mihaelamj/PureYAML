@testable import PureYAML
import Testing

@Suite("Downstream Documents")
struct DownstreamDocumentTests {
    @Test("Parses OpenAPI-style document fixture with exact representative paths")
    func test_openAPIStyleDocumentFixture() throws {
        let root = try requireRootMapping(openAPIStyleDocumentYAML)

        #expect(root.pairs.map(\.key) == ["openapi", "info", "servers", "paths", "components"])
        #expect(root["openapi"] == .string("3.1.0"))
        #expect(root["swagger"] == nil)

        let info = expectMapping(root["info"], "expected info mapping")
        #expect(info?["title"] == .string("Article API"))
        #expect(info?["version"] == .string("1.2.3"))

        let servers = requireSequence(root["servers"], "expected servers sequence")
        #expect(servers?.count == 1)
        let server = expectMapping(servers?.first, "expected first server mapping")
        #expect(server?["url"] == .string("https://api.example.com"))

        let paths = expectMapping(root["paths"], "expected paths mapping")
        #expect(paths?["/missing"] == nil)
        let articlePath = expectMapping(paths?["/articles/{id}"], "expected article path mapping")
        let get = expectMapping(articlePath?["get"], "expected get operation mapping")
        #expect(get?.pairs.map(\.key) == ["operationId", "parameters", "responses"])
        #expect(get?["operationId"] == .string("getArticle"))
        #expect(get?["post"] == nil)

        let parameters = requireSequence(get?["parameters"], "expected parameters sequence")
        #expect(parameters?.count == 1)
        let parameter = expectMapping(parameters?.first, "expected parameter mapping")
        #expect(parameter?["name"] == .string("id"))
        #expect(parameter?["in"] == .string("path"))
        #expect(parameter?["required"] == .bool(true))
        let parameterSchema = expectMapping(parameter?["schema"], "expected parameter schema mapping")
        #expect(parameterSchema?["type"] == .string("string"))
        #expect(parameterSchema?["format"] == .string("uuid"))

        let responses = expectMapping(get?["responses"], "expected responses mapping")
        #expect(responses?["404"] == nil)
        let success = expectMapping(responses?["200"], "expected success response mapping")
        #expect(success?["description"] == .string("Article response"))
        let content = expectMapping(success?["content"], "expected content mapping")
        let mediaType = expectMapping(content?["application/json"], "expected json media type mapping")
        let responseSchema = expectMapping(mediaType?["schema"], "expected response schema mapping")
        #expect(responseSchema?["$ref"] == .string("#/components/schemas/Article"))

        let components = expectMapping(root["components"], "expected components mapping")
        let schemas = expectMapping(components?["schemas"], "expected schemas mapping")
        let article = expectMapping(schemas?["Article"], "expected Article schema mapping")
        #expect(article?["type"] == .string("object"))
        let required = requireSequence(article?["required"], "expected required sequence")
        #expect(required == [.string("id"), .string("title"), .string("tags")])

        let properties = expectMapping(article?["properties"], "expected properties mapping")
        let tags = expectMapping(properties?["tags"], "expected tags property mapping")
        #expect(tags?["type"] == .string("array"))
        let tagItems = expectMapping(tags?["items"], "expected tag item mapping")
        #expect(tagItems?["type"] == .string("string"))
        let summary = expectMapping(properties?["summary"], "expected summary property mapping")
        #expect(summary?["nullable"] == .bool(true))
    }

    @Test("Decodes downstream service configuration fixture exactly")
    func test_downstreamServiceConfigurationFixture() throws {
        let parsed = try PureYAML.parse(downstreamServiceDocumentYAML)
        let root = expectMapping(parsed, "expected service configuration mapping")

        #expect(root?.pairs.map(\.key) == ["service", "limits", "owners", "metadata"])
        let service = expectMapping(root?["service"], "expected service mapping")
        #expect(service?["name"] == .string("TileDown"))
        #expect(service?["version"] == .string("0.4.2"))
        #expect(service?["enabled"] == .bool(true))
        #expect(requireSequence(service?["tags"]) == [.string("static"), .string("yaml")])

        let limits = expectMapping(root?["limits"], "expected limits mapping")
        #expect(limits?["retries"] == .int(3))
        #expect(limits?["timeoutSeconds"] == .int(30))

        let owners = requireSequence(root?["owners"], "expected owners sequence")
        #expect(owners?.count == 2)
        let firstOwner = expectMapping(owners?.first, "expected first owner mapping")
        #expect(firstOwner?["name"] == .string("Mihaela"))
        #expect(firstOwner?["email"] == .null)
        let secondOwner = expectMapping(owners?.last, "expected second owner mapping")
        #expect(secondOwner?["email"] == .string("bot@example.com"))

        let metadata = expectMapping(root?["metadata"], "expected metadata mapping")
        #expect(metadata?["region"] == .string("eu"))
        #expect(metadata?["tier"] == .string("production"))
        #expect(metadata?["missing"] == nil)

        #expect(try PureYAML.decode(DownstreamServiceDocument.self, from: parsed) == downstreamServiceDocument)
        #expect(
            try PureYAML.decode(
                DownstreamServiceDocument.self,
                from: downstreamServiceDocumentYAML,
            ) == downstreamServiceDocument,
        )
    }

    @Test("Pins unsupported downstream merge keys as unflattened fallback values")
    func test_downstreamMergeKeyFallbackFixture() throws {
        let root = try requireRootMapping(downstreamMergeKeyYAML)
        let defaults = expectMapping(root["defaults"], "expected defaults mapping")
        let services = expectMapping(root["services"], "expected services mapping")
        let api = expectMapping(services?["api"], "expected api service mapping")
        let merge = expectMapping(api?["<<"], "expected unflattened merge mapping")

        #expect(root.pairs.map(\.key) == ["defaults", "services"])
        #expect(api?.pairs.map(\.key) == ["<<", "name"])
        #expect(defaults?["retries"] == .int(3))
        #expect(defaults?["timeoutSeconds"] == .int(30))
        #expect(merge == defaults)
        #expect(api?["name"] == .string("API"))
        #expect(api?["retries"] == nil)
        #expect(api?["timeoutSeconds"] == nil)
        #expect(PureYAML.Validation.Validator().collect(.mapping(root)) == .init())
    }

    func requireRootMapping(_ yaml: String) throws -> PureYAML.Model.Mapping {
        guard case let .mapping(mapping) = try PureYAML.parse(yaml) else {
            recordIssue("expected root mapping")
            return .init()
        }
        return mapping
    }

    func expectMapping(
        _ value: PureYAML.Model.Value?,
        _ message: String,
    ) -> PureYAML.Model.Mapping? {
        guard case let .mapping(mapping)? = value else {
            recordIssue(message)
            return nil
        }
        return mapping
    }
}
