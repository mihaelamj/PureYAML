@testable import PureYAML

enum UnsupportedYAMLGapsFixtures {
    struct ParseErrorCase: CustomStringConvertible {
        var name: String
        var yaml: String
        var expected: PureYAML.Parsing.ParseError
        var expectedDescription: String

        var description: String {
            name
        }
    }

    struct FallbackValueCase: CustomStringConvertible {
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

    static let parseErrors: [ParseErrorCase] = [
        ParseErrorCase(
            name: "second document start marker",
            yaml: """
            ---
            - Mark McGwire
            ---
            - Sammy Sosa
            """,
            expected: .unsupportedMultiDocumentStream(line: 3),
            expectedDescription: "multi-document streams are not supported at line 3",
        ),
        ParseErrorCase(
            name: "content after explicit document end",
            yaml: """
            name: First
            ...
            name: Second
            """,
            expected: .unsupportedMultiDocumentStream(line: 3),
            expectedDescription: "multi-document streams are not supported at line 3",
        ),
        ParseErrorCase(
            name: "unknown directive",
            yaml: """
            %FOO bar
            value: one
            """,
            expected: .unsupportedDirective(name: "%FOO", line: 1),
            expectedDescription: "unsupported directive '%FOO' at line 1",
        ),
        ParseErrorCase(
            name: "tag directive after content",
            yaml: """
            value: one
            %TAG !e! tag:example.com,2026:
            """,
            expected: .unsupportedDirective(name: "%TAG", line: 2),
            expectedDescription: "unsupported directive '%TAG' at line 2",
        ),
        ParseErrorCase(
            name: "tag directive after document start",
            yaml: """
            ---
            %TAG !e! tag:example.com,2026:
            value: !e!thing one
            """,
            expected: .unsupportedDirective(name: "%TAG", line: 2),
            expectedDescription: "unsupported directive '%TAG' at line 2",
        ),
    ]

    static let fallbackValues: [FallbackValueCase] = [
        FallbackValueCase(
            name: "unsupported built-in tags remain value trees",
            yaml: """
            date: !!timestamp 2001-01-23
            payload: !!binary |
              YWJj
            set: !!set {a: null}
            omap: !!omap [{a: 1}, {b: 2}]
            """,
            expected: .mapping(.init([
                .init(key: "date", value: .string("2001-01-23")),
                .init(key: "payload", value: .string("YWJj\n")),
                .init(key: "set", value: .mapping(.init([
                    .init(key: "a", value: .null),
                ]))),
                .init(key: "omap", value: .sequence([
                    .mapping(.init([
                        .init(key: "a", value: .int(1)),
                    ])),
                    .mapping(.init([
                        .init(key: "b", value: .int(2)),
                    ])),
                ])),
            ])),
        ),
        FallbackValueCase(
            name: "comments after explicit document end stay non-content",
            yaml: """
            name: First
            ...
            # trailing comment
            """,
            expected: .mapping(.init([
                .init(key: "name", value: .string("First")),
            ])),
        ),
    ]

    static let directPreservedValue = PureYAML.Model.Value.mapping(.init([
        .init(key: "<<", value: .mapping(.init([
            .init(key: "enabled", value: .bool(true)),
        ]))),
        .init(key: "title", value: .string("First")),
        .init(key: "title", value: .string("Second")),
    ]))

    static let directPreservedIssues: [PureYAML.Validation.Issue] = [
        .init(
            severity: .error,
            reason: "Duplicate mapping key 'title'",
            path: .init([.key("title")]),
        ),
    ]
}
