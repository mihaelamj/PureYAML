@testable import PureYAML

enum LiteralBlockEmissionFixtures {
    struct Case: CustomStringConvertible {
        var name: String
        var value: PureYAML.Model.Value
        var expected: String
        var required: [String]
        var forbidden: [String]

        var description: String {
            name
        }
    }

    static let supported: [Case] = [
        Case(
            name: "hash without comment boundary",
            value: .mapping(.init([
                .init(key: "body", value: .string("swift#wasm\nnext")),
            ])),
            expected: """
            body: |-
              swift#wasm
              next

            """,
            required: ["body: |-", "swift#wasm", "next"],
            forbidden: ["swift#wasm\\nnext", "\"swift#wasm"],
        ),
        Case(
            name: "plain-safe indicator-like content",
            value: .mapping(.init([
                .init(key: "body", value: .string("-dash\n?question\n:colon\n%percent\n@at")),
            ])),
            expected: """
            body: |-
              -dash
              ?question
              :colon
              %percent
              @at

            """,
            required: ["-dash", "?question", ":colon", "%percent", "@at"],
            forbidden: ["\"-dash", "\\n?question"],
        ),
    ]

    static let fallbacks: [Case] = [
        Case(
            name: "comment boundary stays quoted",
            value: .mapping(.init([
                .init(key: "body", value: .string("swift # wasm\nnext")),
            ])),
            expected: """
            body: "swift # wasm\\nnext"

            """,
            required: ["\"swift # wasm\\nnext\""],
            forbidden: ["body: |", "swift # wasm\n"],
        ),
        Case(
            name: "mapping separator at end stays quoted",
            value: .mapping(.init([
                .init(key: "body", value: .string("key:\nnext")),
            ])),
            expected: """
            body: "key:\\nnext"

            """,
            required: ["\"key:\\nnext\""],
            forbidden: ["body: |", "  key:"],
        ),
        Case(
            name: "mapping separator before comma stays quoted",
            value: .mapping(.init([
                .init(key: "body", value: .string("key:,\nnext")),
            ])),
            expected: """
            body: "key:,\\nnext"

            """,
            required: ["\"key:,\\nnext\""],
            forbidden: ["body: |", "  key:,"],
        ),
        Case(
            name: "structural indicator line stays quoted",
            value: .mapping(.init([
                .init(key: "body", value: .string("- item\nnext")),
            ])),
            expected: """
            body: "- item\\nnext"

            """,
            required: ["\"- item\\nnext\""],
            forbidden: ["body: |", "  - item"],
        ),
        Case(
            name: "blank content line stays quoted",
            value: .mapping(.init([
                .init(key: "body", value: .string("one\n\ntwo")),
            ])),
            expected: """
            body: "one\\n\\ntwo"

            """,
            required: ["\"one\\n\\ntwo\""],
            forbidden: ["body: |", "  one\n\n  two"],
        ),
        Case(
            name: "quoted-looking content stays quoted",
            value: .mapping(.init([
                .init(key: "body", value: .string("\"quoted\"\nnext")),
            ])),
            expected: """
            body: "\\"quoted\\"\\nnext"

            """,
            required: ["\"\\\"quoted\\\"\\nnext\""],
            forbidden: ["body: |", "  \"quoted\""],
        ),
    ]
}
