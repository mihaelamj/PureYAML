@testable import PureYAML

enum ScalarCompatibilityFixtures {
    enum Expected {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case nan
        case string(String)
    }

    struct SuccessCase {
        var yaml: String
        var expected: Expected
        var forbiddenString: String?

        init(
            _ yaml: String,
            _ expected: Expected,
            forbiddenString: String? = nil,
        ) {
            self.yaml = yaml
            self.expected = expected
            self.forbiddenString = forbiddenString
        }
    }

    struct ErrorCase {
        var yaml: String
        var expected: PureYAML.Parsing.ParseError
    }

    static let resolvedScalars: [SuccessCase] = [
        SuccessCase("value:", .null),
        SuccessCase("value: ~", .null, forbiddenString: "~"),
        SuccessCase("value: null", .null, forbiddenString: "null"),
        SuccessCase("value: Null", .null, forbiddenString: "Null"),
        SuccessCase("value: NULL", .null, forbiddenString: "NULL"),
        SuccessCase("value: true", .bool(true), forbiddenString: "true"),
        SuccessCase("value: True", .bool(true), forbiddenString: "True"),
        SuccessCase("value: TRUE", .bool(true), forbiddenString: "TRUE"),
        SuccessCase("value: yes", .bool(true), forbiddenString: "yes"),
        SuccessCase("value: Yes", .bool(true), forbiddenString: "Yes"),
        SuccessCase("value: YES", .bool(true), forbiddenString: "YES"),
        SuccessCase("value: on", .bool(true), forbiddenString: "on"),
        SuccessCase("value: On", .bool(true), forbiddenString: "On"),
        SuccessCase("value: ON", .bool(true), forbiddenString: "ON"),
        SuccessCase("value: false", .bool(false), forbiddenString: "false"),
        SuccessCase("value: False", .bool(false), forbiddenString: "False"),
        SuccessCase("value: FALSE", .bool(false), forbiddenString: "FALSE"),
        SuccessCase("value: no", .bool(false), forbiddenString: "no"),
        SuccessCase("value: No", .bool(false), forbiddenString: "No"),
        SuccessCase("value: NO", .bool(false), forbiddenString: "NO"),
        SuccessCase("value: off", .bool(false), forbiddenString: "off"),
        SuccessCase("value: Off", .bool(false), forbiddenString: "Off"),
        SuccessCase("value: OFF", .bool(false), forbiddenString: "OFF"),
        SuccessCase("value: 12345", .int(12345), forbiddenString: "12345"),
        SuccessCase("value: +12345", .int(12345), forbiddenString: "+12345"),
        SuccessCase("value: -7", .int(-7), forbiddenString: "-7"),
        SuccessCase("value: 0o14", .int(12), forbiddenString: "0o14"),
        SuccessCase("value: 014", .int(12), forbiddenString: "014"),
        SuccessCase("value: 0xC", .int(12), forbiddenString: "0xC"),
        SuccessCase("value: 0b1010", .int(10), forbiddenString: "0b1010"),
        SuccessCase("value: 1_000", .int(1000), forbiddenString: "1_000"),
        SuccessCase("value: 1.23015e+3", .double(1230.15), forbiddenString: "1.23015e+3"),
        SuccessCase("value: 12.3015e+02", .double(1230.15), forbiddenString: "12.3015e+02"),
        SuccessCase("value: 1230.15", .double(1230.15), forbiddenString: "1230.15"),
        SuccessCase("value: 1_000.25", .double(1000.25), forbiddenString: "1_000.25"),
        SuccessCase("value: -.inf", .double(-.infinity), forbiddenString: "-.inf"),
        SuccessCase("value: +.INF", .double(.infinity), forbiddenString: "+.INF"),
        SuccessCase("value: .NaN", .nan, forbiddenString: ".NaN"),
    ]

    static let explicitScalarTags: [SuccessCase] = [
        SuccessCase("value: !!str true", .string("true")),
        SuccessCase("value: !<tag:yaml.org,2002:str> 0xC", .string("0xC")),
        SuccessCase("value: !!int 0xC", .int(12), forbiddenString: "0xC"),
        SuccessCase("value: !!int \"1_000\"", .int(1000), forbiddenString: "1_000"),
        SuccessCase("value: !<tag:yaml.org,2002:int> 0b1010", .int(10), forbiddenString: "0b1010"),
        SuccessCase("value: !!float .NaN", .nan, forbiddenString: ".NaN"),
        SuccessCase("value: !!float \"-.inf\"", .double(-.infinity), forbiddenString: "-.inf"),
        SuccessCase("value: !!bool YES", .bool(true), forbiddenString: "YES"),
        SuccessCase("value: !!bool \"off\"", .bool(false), forbiddenString: "off"),
        SuccessCase("value: !!null ignored", .null, forbiddenString: "ignored"),
        SuccessCase(
            """
            %YAML 1.2
            %TAG !yaml! tag:yaml.org,2002:
            ---
            value: !yaml!bool On
            """,
            .bool(true),
            forbiddenString: "On",
        ),
    ]

    static let stringScalars: [SuccessCase] = [
        SuccessCase("value: \"true\"", .string("true")),
        SuccessCase("value: 'false'", .string("false")),
        SuccessCase("value: \"0xC\"", .string("0xC")),
        SuccessCase("value: '1_000'", .string("1_000")),
        SuccessCase("value: !!str yes", .string("yes")),
        SuccessCase("value: !<tag:yaml.org,2002:str> .nan", .string(".nan")),
    ]

    static let unsupportedScalars: [SuccessCase] = [
        SuccessCase("value: 1:20", .string("1:20")),
        SuccessCase("value: 2002-04-28", .string("2002-04-28")),
        SuccessCase("value: 09", .string("09")),
    ]

    static let invalidExplicitScalarTags: [ErrorCase] = [
        ErrorCase(
            yaml: "value: !!int nope",
            expected: .invalidTaggedScalar(
                tag: "tag:yaml.org,2002:int",
                value: "nope",
                line: 1,
                column: 8,
            ),
        ),
        ErrorCase(
            yaml: "value: !!int 0xG",
            expected: .invalidTaggedScalar(
                tag: "tag:yaml.org,2002:int",
                value: "0xG",
                line: 1,
                column: 8,
            ),
        ),
        ErrorCase(
            yaml: "value: !!float nope",
            expected: .invalidTaggedScalar(
                tag: "tag:yaml.org,2002:float",
                value: "nope",
                line: 1,
                column: 8,
            ),
        ),
        ErrorCase(
            yaml: "value: !!bool maybe",
            expected: .invalidTaggedScalar(
                tag: "tag:yaml.org,2002:bool",
                value: "maybe",
                line: 1,
                column: 8,
            ),
        ),
    ]
}
