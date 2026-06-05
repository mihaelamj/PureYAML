@testable import PureYAML
import Testing

@Suite("Codable Compatibility")
struct CodableCompatibilityTests {
    @Test("Dictionary-like dynamic keys decode from ordered mappings")
    func test_dictionaryLikeDynamicKeysDecodeFromOrderedMappings() throws {
        let decoded = try PureYAML.decode(
            DynamicSettings.self,
            from: dynamicSettingsValue,
        )

        #expect(decoded == DynamicSettings(entries: [
            .init(key: "/users", value: 2),
            .init(key: "name.with.dot", value: 3),
        ]))
    }

    @Test("Dictionary-like dynamic keys encode exact values and YAML")
    func test_dictionaryLikeDynamicKeysEncodeExactValuesAndYAML() throws {
        let settings = DynamicSettings(entries: [
            .init(key: "/users", value: 2),
            .init(key: "name.with.dot", value: 3),
        ])

        let yaml = try PureYAML.encodeToYAML(settings)

        #expect(try PureYAML.encode(settings) == dynamicSettingsValue)
        #expect(yaml == """
        /users: 2
        name.with.dot: 3

        """)
        #expect(yaml.contains("/users: 2"))
        #expect(yaml.contains("name.with.dot: 3"))
        #expect(!yaml.contains("\"name.with.dot\""))
        #expect(!yaml.contains("null"))
    }

    @Test("Dictionary values decode where YAML mapping semantics allow them")
    func test_dictionaryValuesDecodeWhereYAMLSemanticsAllowThem() throws {
        let decoded = try PureYAML.decode(
            [String: Int].self,
            from: .mapping(.init([
                .init(key: "count", value: .int(2)),
            ])),
        )

        #expect(decoded == ["count": 2])
    }

    @Test("Nested keyed unkeyed and single-value interactions round trip exactly")
    func test_nestedKeyedUnkeyedAndSingleValueInteractionsRoundTripExactly() throws {
        let decoded = try PureYAML.decode(
            NestedCompatibilityDocument.self,
            from: nestedCompatibilityValue,
        )
        let yaml = try PureYAML.encodeToYAML(nestedCompatibilityFixture)

        #expect(decoded == nestedCompatibilityFixture)
        #expect(try PureYAML.encode(nestedCompatibilityFixture) == nestedCompatibilityValue)
        #expect(yaml == """
        title: "Typed YAML"
        metadata:
          author: "Mihaela"
          rating: 5
        sections:
          -
            heading: "Intro"
            items:
              - "one"
              - "two"
          -
            heading: "Outro"
            items:

        """)
        #expect(yaml.contains("sections:"))
        #expect(!yaml.contains("summary:"))
    }

    @Test("Dynamic-key decoding reports exact punctuation paths")
    func test_dynamicKeyDecodingReportsExactPunctuationPaths() {
        expectDecodingError(
            .typeMismatch(
                expected: "Int",
                actual: "string",
                path: .init([.key("/users")]),
            ),
        ) {
            _ = try PureYAML.decode(DynamicSettings.self, from: .mapping(.init([
                .init(key: "/users", value: .string("two")),
            ])))
        }
    }

    @Test("Dynamic-key decoding validates duplicate punctuation keys")
    func test_dynamicKeyDecodingValidatesDuplicatePunctuationKeys() {
        expectValidationError {
            _ = try PureYAML.decode(DynamicSettings.self, from: .mapping(.init([
                .init(key: "/users", value: .int(1)),
                .init(key: "/users", value: .int(2)),
            ])))
        } check: { collection in
            #expect(collection.issues == [
                .init(
                    severity: .error,
                    reason: "Duplicate mapping key '/users'",
                    path: .init([.key("/users")]),
                ),
            ])
            #expect(collection.description == "error: Duplicate mapping key '/users' at $[\"/users\"]")
        }
    }

    @Test("Keyed super decoders and encoders preserve exact payloads")
    func test_keyedSuperDecodersAndEncodersPreserveExactPayloads() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "payload", value: .mapping(.init([
                .init(key: "value", value: .string("child")),
            ]))),
        ]))
        let box = KeyedSuperBox(payload: .init(value: "child"))

        #expect(try PureYAML.decode(KeyedSuperBox.self, from: value) == box)
        #expect(try PureYAML.encode(box) == value)
        #expect(try PureYAML.encodeToYAML(box) == """
        payload:
          value: "child"

        """)
    }

    @Test("Keyed default super coders use the super key")
    func test_keyedDefaultSuperCodersUseTheSuperKey() throws {
        let value = PureYAML.Model.Value.mapping(.init([
            .init(key: "super", value: .mapping(.init([
                .init(key: "value", value: .string("child")),
            ]))),
        ]))
        let box = KeyedDefaultSuperBox(payload: .init(value: "child"))

        #expect(try PureYAML.decode(KeyedDefaultSuperBox.self, from: value) == box)
        #expect(try PureYAML.encode(box) == value)
        #expect(try PureYAML.encodeToYAML(box) == """
        super:
          value: "child"

        """)
    }

    @Test("Keyed super encoders reserve distinct keys before values are written")
    func test_keyedSuperEncodersReserveDistinctKeysBeforeValuesAreWritten() throws {
        #expect(try PureYAML.encode(DelayedKeyedSuperEncoders()) == .mapping(.init([
            .init(key: "first", value: .string("one")),
            .init(key: "second", value: .string("two")),
        ])))
    }

    @Test("Nested coders expose exact coding paths")
    func test_nestedCodersExposeExactCodingPaths() throws {
        #expect(try PureYAML.encode(KeyedCodingPathEncodingProbe()) == codingPathProbeValue)

        _ = try PureYAML.decode(
            KeyedCodingPathDecodingProbe.self,
            from: codingPathProbeValue,
        )
    }

    @Test("Unsupported missing super decoder payload reports exact errors")
    func test_unsupportedMissingSuperDecoderPayloadReportsExactErrors() {
        expectDecodingError(
            .keyNotFound(key: "payload", path: .init([.key("payload")])),
        ) {
            _ = try PureYAML.decode(MissingPayloadBox.self, from: .mapping(.init()))
        }
    }

    @Test("Unsupported missing default super decoder reports exact errors")
    func test_unsupportedMissingDefaultSuperDecoderReportsExactErrors() {
        expectDecodingError(
            .keyNotFound(key: "super", path: .init([.key("super")])),
        ) {
            _ = try PureYAML.decode(MissingDefaultSuperBox.self, from: .mapping(.init()))
        }
    }

    @Test("Unsupported empty encodable reports exact errors")
    func test_unsupportedEmptyEncodableReportsExactErrors() {
        expectEncodingError(.noValueEncoded(path: .root)) {
            _ = try PureYAML.encode(NoValueEncoded())
        }
    }
}

private func expectDecodingError(
    _ expected: PureYAML.Decoding.Error,
    operation: () throws -> some Any,
) {
    do {
        _ = try operation()
        recordIssue("expected decoding error")
    } catch let error as PureYAML.Decoding.Error {
        #expect(error == expected)
        #expect(error.description == expected.description)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}

private func expectEncodingError(
    _ expected: PureYAML.Encoding.Error,
    operation: () throws -> some Any,
) {
    do {
        _ = try operation()
        recordIssue("expected encoding error")
    } catch let error as PureYAML.Encoding.Error {
        #expect(error == expected)
        #expect(error.description == expected.description)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}

private func expectValidationError(
    operation: () throws -> some Any,
    check: (PureYAML.Validation.Issue.Collection) -> Void,
) {
    do {
        _ = try operation()
        recordIssue("expected validation error")
    } catch let collection as PureYAML.Validation.Issue.Collection {
        check(collection)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}

func expectCodingPath(
    _ path: [any CodingKey],
    strings: [String],
    intValues: [Int?],
) {
    #expect(path.map(\.stringValue) == strings)
    #expect(path.map(\.intValue) == intValues)
}
