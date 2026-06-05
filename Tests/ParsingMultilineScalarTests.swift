@testable import PureYAML
import Testing

@Suite("Parsing Multiline Scalars")
struct ParsingMultilineScalarTests {
    @Test("Parses multiline plain scalars in mappings")
    func test_multilinePlainScalarsInMappings() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            columns:
            - description: CreationTimestamp is a timestamp representing the server time when
                this object was created. It is not guaranteed to be set in happens-before
                order across separate operations.
              jsonPath: .metadata.creationTimestamp
            """,
        ))

        let expectedDescription = [
            "CreationTimestamp is a timestamp representing the server time when this object was created.",
            "It is not guaranteed to be set in happens-before order across separate operations.",
        ].joined(separator: " ")
        let column = root?.sequence("columns")?.first?.mapping
        #expect(column?["description"] == .string(expectedDescription))
        #expect(column?["jsonPath"] == .string(".metadata.creationTimestamp"))
        #expect(column?["missing"] == nil)
    }

    @Test("Parses multiline plain scalars before the next sequence entry")
    func test_multilinePlainScalarsBeforeNextSequenceEntry() throws {
        let value = try PureYAML.parse(
            """
            - name: code-quality
              description: Insights into reliability, maintainability, and efficiency of your
                codebase.
            - name: codespaces
              description: Endpoints to manage Codespaces using the REST API.
            """,
        )

        let tags = requireSequence(value)
        let first = tags?.first?.mapping
        let second = tags?.dropFirst().first?.mapping

        #expect(first?["name"] == .string("code-quality"))
        #expect(first?["description"] == .string("Insights into reliability, maintainability, and efficiency of your codebase."))
        #expect(second?["name"] == .string("codespaces"))
        #expect(second?["description"] == .string("Endpoints to manage Codespaces using the REST API."))
        #expect(first?["missing"] == nil)
    }

    @Test("Parses multiline plain scalar sequence items")
    func test_multilinePlainScalarSequenceItems() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            examples:
            - Updated instructions to help the team with planning and coordination
              tasks
            next: done
            """,
        ))

        #expect(root?.sequence("examples") == [
            .string("Updated instructions to help the team with planning and coordination tasks"),
        ])
        #expect(root?["next"] == .string("done"))
        #expect(root?["missing"] == nil)
    }

    @Test("Parses multiline plain scalar continuations that start with quotes")
    func test_multilinePlainScalarContinuationsThatStartWithQuotes() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            get:
              description: Gets a team using the team's slug. To create the slug, GitHub replaces
                special characters in the name string, changes all words to lowercase, and
                replaces spaces with a `-` separator and adds the "ent:" prefix. For example,
                "My TEam Näme" would become `ent:my-team-name`.
              tags:
              - enterprise-teams
            """,
        ))

        let expectedDescription = [
            "Gets a team using the team's slug.",
            "To create the slug, GitHub replaces special characters in the name string,",
            "changes all words to lowercase, and replaces spaces with a `-` separator",
            "and adds the \"ent:\" prefix. For example,",
            "\"My TEam Näme\" would become `ent:my-team-name`.",
        ].joined(separator: " ")
        let get = root?.mapping("get")
        #expect(get?["description"] == .string(expectedDescription))
        #expect(get?.sequence("tags") == [.string("enterprise-teams")])
        #expect(get?["missing"] == nil)
    }

    @Test("Parses multiline plain scalar continuations that start with flow markers")
    func test_multilinePlainScalarContinuationsThatStartWithFlowMarkers() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            selected_repository_ids:
              description: An array of repository ids that can access the organization
                secret. You can manage the list of
                selected repositories using the [List selected repositories for
                an organization secret](https://docs.example.com/list),
                [Set selected repositories for an organization secret](https://docs.example.com/set),
                and [Remove selected repository from an organization secret](https://docs.example.com/remove)
                endpoints.
              items:
                type: integer
            """,
        ))

        let expectedDescription = [
            "An array of repository ids that can access the organization secret.",
            "You can manage the list of selected repositories using the",
            "[List selected repositories for an organization secret](https://docs.example.com/list),",
            "[Set selected repositories for an organization secret](https://docs.example.com/set),",
            "and [Remove selected repository from an organization secret](https://docs.example.com/remove) endpoints.",
        ].joined(separator: " ")
        let selected = root?.mapping("selected_repository_ids")
        #expect(selected?["description"] == .string(expectedDescription))
        #expect(selected?.mapping("items")?["type"] == .string("integer"))
        #expect(selected?["missing"] == nil)
    }

    @Test("Parses flow-marker continuations after previous sequence indentation")
    func test_flowMarkerContinuationsAfterPreviousSequenceIndentation() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            schema:
              enum:
                - all
                - private
              selected_repository_ids:
                description: An array of repository ids that can access the organization
                  [Set selected repositories](https://docs.example.com/set),
                  and more.
                items:
                  type: integer
            """,
        ))

        let selected = root?.mapping("schema")?.mapping("selected_repository_ids")
        #expect(
            selected?["description"] ==
                .string("An array of repository ids that can access the organization [Set selected repositories](https://docs.example.com/set), and more."),
        )
        #expect(selected?.mapping("items")?["type"] == .string("integer"))
        #expect(selected?["missing"] == nil)
        #expect(root?.mapping("schema")?.sequence("enum") == [.string("all"), .string("private")])
    }

    @Test("Parses colon-style markup inside multiline plain scalars")
    func test_colonStyleMarkupInsideMultilinePlainScalars() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            label:
              description: The name of the label. Emoji can be added to label
                names, using either native emoji or colon-style markup. For example,
                typing `:strawberry:` will render the emoji ![:strawberry:](https://example.com/1f353.png
                ":strawberry:"). For a full list of available emoji and codes.
              color: f29513
            """,
        ))

        let expectedDescription = [
            "The name of the label. Emoji can be added to label names,",
            "using either native emoji or colon-style markup. For example,",
            "typing `:strawberry:` will render the emoji",
            "![:strawberry:](https://example.com/1f353.png \":strawberry:\").",
            "For a full list of available emoji and codes.",
        ].joined(separator: " ")
        #expect(root?.mapping("label")?["description"] == .string(expectedDescription))
        #expect(root?.mapping("label")?["color"] == .string("f29513"))
        #expect(root?.mapping("label")?["missing"] == nil)
    }

    @Test("Parses block scalar text that starts with YAML indicators")
    func test_blockScalarTextThatStartsWithYAMLIndicators() throws {
        let root = try requireMapping(PureYAML.parse(
            """
            description: |
              **Fine-grained access tokens**

              * [GitHub App user access tokens](https://docs.github.com)
              - dash list item stays text
            """,
        ))

        #expect(root?["description"] == .string(
            """
            **Fine-grained access tokens**
            * [GitHub App user access tokens](https://docs.github.com)
            - dash list item stays text

            """,
        ))
    }
}
