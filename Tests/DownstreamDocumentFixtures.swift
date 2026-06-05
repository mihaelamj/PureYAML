@testable import PureYAML

let openAPIStyleDocumentYAML = """
openapi: 3.1.0
info:
  title: Article API
  version: 1.2.3
servers:
  - url: https://api.example.com
paths:
  /articles/{id}:
    get:
      operationId: getArticle
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        "200":
          description: Article response
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Article"
components:
  schemas:
    Article:
      type: object
      required: [id, title, tags]
      properties:
        id: {type: string, format: uuid}
        title:
          type: string
        tags:
          type: array
          items:
            type: string
        summary:
          type: string
          nullable: true
"""

let downstreamServiceDocumentYAML = """
service:
  name: TileDown
  version: "0.4.2"
  enabled: true
  tags: [static, yaml]
limits:
  retries: 3
  timeoutSeconds: 30
owners:
  - name: Mihaela
    email:
  - name: Build Bot
    email: bot@example.com
metadata:
  region: eu
  tier: production
"""

let downstreamServiceDocument = DownstreamServiceDocument(
    service: .init(
        name: "TileDown",
        version: "0.4.2",
        enabled: true,
        tags: ["static", "yaml"],
    ),
    limits: .init(retries: 3, timeoutSeconds: 30),
    owners: [
        .init(name: "Mihaela", email: nil),
        .init(name: "Build Bot", email: "bot@example.com"),
    ],
    metadata: [
        "region": "eu",
        "tier": "production",
    ],
)

let downstreamMergeKeyYAML = """
defaults: &serviceDefaults {retries: 3, timeoutSeconds: 30}
services:
  api:
    <<: *serviceDefaults
    name: API
"""

struct DownstreamServiceDocument: Codable, Equatable {
    var service: DownstreamService
    var limits: DownstreamLimits
    var owners: [DownstreamOwner]
    var metadata: [String: String]
}

struct DownstreamService: Codable, Equatable {
    var name: String
    var version: String
    var enabled: Bool
    var tags: [String]
}

struct DownstreamLimits: Codable, Equatable {
    var retries: Int
    var timeoutSeconds: Int
}

struct DownstreamOwner: Codable, Equatable {
    var name: String
    var email: String?
}
