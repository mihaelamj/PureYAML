@testable import PureYAML
import Testing

@Suite("Preflight Scanner")
struct PreflightScannerTests {
    @Test("Reports exact line diagnostics for common production spacing failures", arguments: preflightLineCases)
    func test_reportsExactLineDiagnosticsForCommonProductionSpacingFailures(testCase: PreflightLineCase) {
        let scanner = PureYAML.Validation.PreflightScanner()

        #expect(scanner.diagnostics(
            in: testCase.line,
            file: "input.yaml",
            line: testCase.lineNumber,
        ) == [testCase.expected])
    }

    @Test("Does not report false positives for valid scalar-like text")
    func test_doesNotReportFalsePositivesForValidScalarLikeText() {
        let scanner = PureYAML.Validation.PreflightScanner()
        let yaml = [
            "negative: -1",
            "url: https://example.com",
            "flow: {name:value}",
            "- plain sequence item",
            "---",
            "# comment:without space",
        ].joined(separator: "\n")

        #expect(scanner.diagnostics(in: yaml).isEmpty)
    }

    @Test("Scans the full damaged file instead of stopping at the first bad line")
    func test_scansFullDamagedFileInsteadOfStoppingAtTheFirstBadLine() {
        let scanner = PureYAML.Validation.PreflightScanner()
        let yaml = productionLikeFaultyYAML

        #expect(scanner.diagnostics(in: yaml, file: "production.yaml") == productionLikeFaultyDiagnostics)
    }
}

struct PreflightLineCase: CustomStringConvertible {
    var name: String
    var line: String
    var lineNumber: Int
    var expected: PureYAML.Validation.Diagnostic

    var description: String {
        name
    }
}

let preflightLineCases: [PreflightLineCase] = [
    .init(
        name: "tab indentation",
        line: "\tname: value",
        lineNumber: 7,
        expected: .init(
            kind: .parse,
            code: "tabIndentation",
            severity: .error,
            file: "input.yaml",
            line: 7,
            column: 1,
            reason: "tab used for indentation; YAML indentation must use spaces",
        ),
    ),
    .init(
        name: "missing mapping space",
        line: "summary:Missing space",
        lineNumber: 8,
        expected: .init(
            kind: .parse,
            code: "missingMappingSpace",
            severity: .error,
            file: "input.yaml",
            line: 8,
            column: 9,
            reason: "missing space after ':' in mapping entry",
        ),
    ),
    .init(
        name: "missing sequence space",
        line: "        -name: id",
        lineNumber: 9,
        expected: .init(
            kind: .parse,
            code: "missingSequenceSpace",
            severity: .error,
            file: "input.yaml",
            line: 9,
            column: 10,
            reason: "missing space after '-' in sequence entry",
        ),
    ),
    .init(
        name: "trailing whitespace",
        line: "description: OK  ",
        lineNumber: 10,
        expected: .init(
            kind: .parse,
            code: "trailingWhitespace",
            severity: .warning,
            file: "input.yaml",
            line: 10,
            column: 16,
            reason: "trailing whitespace",
        ),
    ),
    .init(
        name: "invalid control character",
        line: "control: \u{0007}",
        lineNumber: 11,
        expected: .init(
            kind: .parse,
            code: "invalidControlCharacter",
            severity: .error,
            file: "input.yaml",
            line: 11,
            column: 10,
            reason: "invalid control character in YAML source",
        ),
    ),
]

let productionLikeFaultyYAML = [
    "\tapiVersion: v1",
    "kind:Pod",
    "metadata:",
    "  name: app",
    "  labels:",
    "    app:demo",
    "spec:",
    "  containers:",
    "    -name: app",
    "    - image:nginx",
    "    - ports:",
    "        -containerPort:80",
    "env:",
    "  - name:MODE",
    "  - value:prod",
    "description: ok  ",
    "control: \u{0007}",
    "url: https://example.com",
    "negative: -1",
    "flow: {name:value}",
    "replicas:3",
    "  -host: example.com",
    "  - port:8080",
    "  timeout:30",
    "  enabled:true",
    "  path:/health",
    "  query:?bad",
    "  item:[]",
    "  owner:me",
    "  tag:v1",
    "  mode:prod",
].joined(separator: "\n")

let productionLikeFaultyDiagnostics: [PureYAML.Validation.Diagnostic] = [
    .init(
        kind: .parse,
        code: "tabIndentation",
        severity: .error,
        file: "production.yaml",
        line: 1,
        column: 1,
        reason: "tab used for indentation; YAML indentation must use spaces",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 2,
        column: 6,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 6,
        column: 9,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingSequenceSpace",
        severity: .error,
        file: "production.yaml",
        line: 9,
        column: 6,
        reason: "missing space after '-' in sequence entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 10,
        column: 13,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingSequenceSpace",
        severity: .error,
        file: "production.yaml",
        line: 12,
        column: 10,
        reason: "missing space after '-' in sequence entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 14,
        column: 10,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 15,
        column: 11,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "trailingWhitespace",
        severity: .warning,
        file: "production.yaml",
        line: 16,
        column: 16,
        reason: "trailing whitespace",
    ),
    .init(
        kind: .parse,
        code: "invalidControlCharacter",
        severity: .error,
        file: "production.yaml",
        line: 17,
        column: 10,
        reason: "invalid control character in YAML source",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 21,
        column: 10,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingSequenceSpace",
        severity: .error,
        file: "production.yaml",
        line: 22,
        column: 4,
        reason: "missing space after '-' in sequence entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 23,
        column: 10,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 24,
        column: 11,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 25,
        column: 11,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 26,
        column: 8,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 27,
        column: 9,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 28,
        column: 8,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 29,
        column: 9,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 30,
        column: 7,
        reason: "missing space after ':' in mapping entry",
    ),
    .init(
        kind: .parse,
        code: "missingMappingSpace",
        severity: .error,
        file: "production.yaml",
        line: 31,
        column: 8,
        reason: "missing space after ':' in mapping entry",
    ),
]
