@testable import PureYAML

enum CollectionCompatibilityFixtures {
    struct SuccessCase: CustomStringConvertible {
        var name: String
        var yaml: String
        var expected: PureYAML.Model.Value
        var absentRootKeys: [String]

        var description: String {
            name
        }

        init(
            name: String,
            yaml: String,
            expected: PureYAML.Model.Value,
            absentRootKeys: [String] = ["missing"],
        ) {
            self.name = name
            self.yaml = yaml
            self.expected = expected
            self.absentRootKeys = absentRootKeys
        }
    }

    struct ParseErrorCase: CustomStringConvertible {
        var name: String
        var yaml: String
        var expected: PureYAML.Parsing.ParseError
        var expectedDescription: String

        var description: String {
            name
        }
    }

    struct ValidationCase: CustomStringConvertible {
        var name: String
        var yaml: String
        var expectedIssues: [PureYAML.Validation.Issue]

        var description: String {
            name
        }
    }

    static let supportedCollections: [SuccessCase] = [
        SuccessCase(
            name: "mapping scalars to block sequences",
            yaml: """
            american:
              - Boston Red Sox
              - Detroit Tigers
              - New York Yankees
            national:
              - New York Mets
              - Chicago Cubs
              - Atlanta Braves
            """,
            expected: .mapping(.init([
                .init(key: "american", value: .sequence([
                    .string("Boston Red Sox"),
                    .string("Detroit Tigers"),
                    .string("New York Yankees"),
                ])),
                .init(key: "national", value: .sequence([
                    .string("New York Mets"),
                    .string("Chicago Cubs"),
                    .string("Atlanta Braves"),
                ])),
            ])),
        ),
        SuccessCase(
            name: "block sequence of mappings",
            yaml: """
            -
              name: Mark McGwire
              hr: 65
              avg: 0.278
            -
              name: Sammy Sosa
              hr: 63
              avg: 0.288
            """,
            expected: .sequence([
                .mapping(.init([
                    .init(key: "name", value: .string("Mark McGwire")),
                    .init(key: "hr", value: .int(65)),
                    .init(key: "avg", value: .double(0.278)),
                ])),
                .mapping(.init([
                    .init(key: "name", value: .string("Sammy Sosa")),
                    .init(key: "hr", value: .int(63)),
                    .init(key: "avg", value: .double(0.288)),
                ])),
            ]),
            absentRootKeys: [],
        ),
        SuccessCase(
            name: "flow sequence of sequences",
            yaml: """
            - [name, hr, avg]
            - [Mark McGwire, 65, 0.278]
            - [Sammy Sosa, 63, 0.288]
            """,
            expected: .sequence([
                .sequence([.string("name"), .string("hr"), .string("avg")]),
                .sequence([.string("Mark McGwire"), .int(65), .double(0.278)]),
                .sequence([.string("Sammy Sosa"), .int(63), .double(0.288)]),
            ]),
            absentRootKeys: [],
        ),
        SuccessCase(
            name: "mapping of flow mappings",
            yaml: """
            Mark McGwire: {hr: 65, avg: 0.278}
            Sammy Sosa: {hr: 63, avg: 0.288}
            """,
            expected: .mapping(.init([
                .init(key: "Mark McGwire", value: .mapping(.init([
                    .init(key: "hr", value: .int(65)),
                    .init(key: "avg", value: .double(0.278)),
                ]))),
                .init(key: "Sammy Sosa", value: .mapping(.init([
                    .init(key: "hr", value: .int(63)),
                    .init(key: "avg", value: .double(0.288)),
                ]))),
            ])),
        ),
        SuccessCase(
            name: "scalar anchor reused through aliases",
            yaml: """
            hr:
              - Mark McGwire
              - &SS Sammy Sosa
            rbi:
              - *SS
              - Ken Griffey
            """,
            expected: .mapping(.init([
                .init(key: "hr", value: .sequence([
                    .string("Mark McGwire"),
                    .string("Sammy Sosa"),
                ])),
                .init(key: "rbi", value: .sequence([
                    .string("Sammy Sosa"),
                    .string("Ken Griffey"),
                ])),
            ])),
        ),
        SuccessCase(
            name: "mapping anchor reused through alias",
            yaml: """
            defaults: &defaults {enabled: true, retries: 3}
            service: *defaults
            """,
            expected: .mapping(.init([
                .init(key: "defaults", value: .mapping(.init([
                    .init(key: "enabled", value: .bool(true)),
                    .init(key: "retries", value: .int(3)),
                ]))),
                .init(key: "service", value: .mapping(.init([
                    .init(key: "enabled", value: .bool(true)),
                    .init(key: "retries", value: .int(3)),
                ]))),
            ])),
        ),
        SuccessCase(
            name: "mapping value with indentless sequence of inline mappings",
            yaml: """
            schema:
              allOf:
              - $ref: '#/components/schemas/ErrorCategory'
              - description: An integer value that specifies the category of a query
                  failure error. Values include 1 - System, 2 - User, and 3
                  - Other.
            """,
            expected: .mapping(.init([
                .init(key: "schema", value: .mapping(.init([
                    .init(key: "allOf", value: .sequence([
                        .mapping(.init([
                            .init(
                                key: "$ref",
                                value: .string("#/components/schemas/ErrorCategory"),
                            ),
                        ])),
                        .mapping(.init([
                            .init(
                                key: "description",
                                value: .string(
                                    "An integer value that specifies the category of a query "
                                        + "failure error. Values include 1 - System, 2 - User, and 3 "
                                        + "- Other.",
                                ),
                            ),
                        ])),
                    ])),
                ]))),
            ])),
        ),
    ]

    static let parseErrors: [ParseErrorCase] = [
        ParseErrorCase(
            name: "undefined alias in mapping value",
            yaml: "root: *missing",
            expected: .undefinedAlias(anchor: "missing", line: 1, column: 7),
            expectedDescription: "undefined alias 'missing' at line 1, column 7",
        ),
        ParseErrorCase(
            name: "mixed root mapping and sequence styles",
            yaml: """
            - one
            key: value
            """,
            expected: .mixedCollectionStyles(line: 2),
            expectedDescription: "mapping and sequence entries are mixed at line 2",
        ),
    ]

    static let duplicateKeyValidation: [ValidationCase] = [
        ValidationCase(
            name: "nested block and flow duplicate keys",
            yaml: """
            root:
              title: First
              title: Second
              children:
                - name: One
                  name: Two
            flow: {id: one, id: two}
            """,
            expectedIssues: [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'title'",
                    path: .init([.key("root"), .key("title")]),
                ),
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'name'",
                    path: .init([.key("root"), .key("children"), .index(0), .key("name")]),
                ),
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key 'id'",
                    path: .init([.key("flow"), .key("id")]),
                ),
            ],
        ),
    ]
}
