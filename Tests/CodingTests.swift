@testable import PureYAML
import Testing

@Suite("Typed Coding")
struct CodingTests {
    @Test("Decodes scalar values with exact results")
    func test_decodesScalarValuesWithExactResults() throws {
        #expect(try PureYAML.decode(String.self, from: .string("hello")) == "hello")
        #expect(try PureYAML.decode(Bool.self, from: .bool(true)))
        #expect(try PureYAML.decode(Int.self, from: .int(42)) == 42)
        #expect(try PureYAML.decode(Double.self, from: .double(1.25)) == 1.25)
        #expect(try PureYAML.decode(Double.self, from: .int(2)) == 2.0)

        let optional = try PureYAML.decode(String?.self, from: .null)
        #expect(optional == nil)
    }

    @Test("Parses YAML before decoding scalar values")
    func test_parsesYAMLBeforeDecodingScalarValues() throws {
        #expect(try PureYAML.decode(String.self, from: "hello") == "hello")
        #expect(try PureYAML.decode(Bool.self, from: "true"))
        #expect(try PureYAML.decode(Int.self, from: "7") == 7)
        #expect(try PureYAML.decode(Double.self, from: "1.5") == 1.5)
    }

    @Test("Encoding scalar values produces exact value trees and YAML")
    func test_encodingScalarValuesProducesExactValueTreesAndYAML() throws {
        #expect(try PureYAML.encode("hello") == .string("hello"))
        #expect(try PureYAML.encode(true) == .bool(true))
        #expect(try PureYAML.encode(42) == .int(42))
        #expect(try PureYAML.encode(1.25) == .double(1.25))

        let nilString: String? = nil
        #expect(try PureYAML.encode(nilString) == .null)
        #expect(try PureYAML.encodeToYAML("hello") == "\"hello\"\n")
        #expect(try !((PureYAML.encodeToYAML("hello")).contains("null")))
    }

    @Test("Decoding failures report exact validation-style errors", arguments: [
        CodingErrorCase(
            name: "string from int",
            value: .int(1),
            kind: .string,
            expected: .typeMismatch(expected: "String", actual: "int", path: .root),
        ),
        CodingErrorCase(
            name: "int from double",
            value: .double(1.5),
            kind: .int,
            expected: .typeMismatch(expected: "Int", actual: "double", path: .root),
        ),
        CodingErrorCase(
            name: "bool from null",
            value: .null,
            kind: .bool,
            expected: .typeMismatch(expected: "Bool", actual: "null", path: .root),
        ),
        CodingErrorCase(
            name: "int8 from out-of-range int",
            value: .int(1000),
            kind: .int8,
            expected: .integerOutOfRange(type: "Int8", path: .root),
        ),
    ])
    func test_decodingFailuresReportExactValidationStyleErrors(
        testCase: CodingErrorCase,
    ) {
        testCase.expectFailure()
    }

    @Test("Unsupported unkeyed decoding container reports exact errors")
    func test_unsupportedUnkeyedDecodingContainerReportsExactErrors() {
        expectDecodingError(
            .unsupportedContainer(kind: "unkeyed", path: .root),
        ) {
            _ = try PureYAML.decode([Int].self, from: .sequence([.int(1)]))
        }
    }

    @Test("Unsupported unkeyed encoding containers report exact errors")
    func test_unsupportedUnkeyedEncodingContainersReportExactErrors() {
        expectEncodingError(
            .unsupportedContainer(kind: "unkeyed", path: .init([.index(0)])),
        ) {
            _ = try PureYAML.encode([1, 2])
        }

        expectEncodingError(
            .unsupportedContainer(kind: "unkeyed", path: .root),
        ) {
            _ = try PureYAML.encode([Int]())
        }
    }

    @Test("Out of range integer encoding reports exact errors")
    func test_outOfRangeIntegerEncodingReportsExactErrors() {
        expectEncodingError(
            .integerOutOfRange(type: "UInt64", path: .root),
        ) {
            _ = try PureYAML.encode(UInt64.max)
        }
    }

    @Test("Coding error descriptions are exact")
    func test_codingErrorDescriptionsAreExact() {
        #expect(PureYAML.Decoding.Error.typeMismatch(
            expected: "String",
            actual: "int",
            path: .root,
        ).description == "Expected String at $, found int")

        #expect(PureYAML.Encoding.Error.unsupportedContainer(
            kind: "keyed",
            path: .init([.key("name")]),
        ).description == "Unsupported keyed encoding container at $.name")

        #expect(PureYAML.Decoding.Error.integerOutOfRange(
            type: "Int8",
            path: .root,
        ).description == "Int8 value is outside PureYAML integer range at $")

        #expect(PureYAML.Encoding.Error.integerOutOfRange(
            type: "UInt64",
            path: .root,
        ).description == "UInt64 value is outside PureYAML integer range at $")
    }
}

struct CodingErrorCase: CustomStringConvertible {
    enum Kind {
        case string
        case int
        case int8
        case bool
    }

    var name: String
    var value: PureYAML.Model.Value
    var kind: Kind
    var expected: PureYAML.Decoding.Error

    var description: String {
        name
    }

    func expectFailure() {
        do {
            switch kind {
            case .string:
                _ = try PureYAML.decode(String.self, from: value)
            case .int:
                _ = try PureYAML.decode(Int.self, from: value)
            case .int8:
                _ = try PureYAML.decode(Int8.self, from: value)
            case .bool:
                _ = try PureYAML.decode(Bool.self, from: value)
            }
            recordIssue("expected decoding error")
        } catch let error as PureYAML.Decoding.Error {
            #expect(error == expected)
            #expect(error.description == expected.description)
        } catch {
            recordIssue("unexpected error \(error)")
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
