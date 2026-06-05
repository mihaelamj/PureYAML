@testable import PureYAML
import Testing

private struct TestFailure: Swift.Error, CustomStringConvertible {
    var description: String
}

func recordIssue(_ message: String) {
    Issue.record(TestFailure(description: message))
}

func requireMapping(
    _ value: PureYAML.Model.Value,
    _ message: String = "expected mapping",
) -> PureYAML.Model.Mapping? {
    guard case let .mapping(mapping) = value else {
        recordIssue(message)
        return nil
    }
    return mapping
}

func requireSequence(
    _ value: PureYAML.Model.Value?,
    _ message: String = "expected sequence",
) -> [PureYAML.Model.Value]? {
    guard case let .sequence(values)? = value else {
        recordIssue(message)
        return nil
    }
    return values
}

func expectParseError(
    _ yaml: String,
    _ expected: PureYAML.Parsing.ParseError,
) {
    expectError(expected) {
        _ = try PureYAML.parse(yaml)
    }
}

func expectError<ExpectedError: Swift.Error & Equatable>(
    _ expected: ExpectedError,
    operation: () throws -> some Any,
) {
    do {
        _ = try operation()
        recordIssue("expected error \(expected)")
    } catch let error as ExpectedError {
        #expect(error == expected)
    } catch {
        recordIssue("unexpected error \(error)")
    }
}
