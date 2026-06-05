extension PureYAML.Parsing.Parser {
    func composeScalarValue(
        _ value: String,
        tag: String?,
        style: PureYAML.Parsing.ScalarStyle,
        mark: PureYAML.Parsing.Mark,
    ) throws -> PureYAML.Model.Value {
        if let tagged = try composeTaggedScalarValue(value, tag: tag, mark: mark) {
            return tagged
        }

        switch style {
        case .folded, .literal:
            return .string(value)
        case .plain:
            return try parseScalar(value, line: mark.line)
        case .doubleQuoted, .singleQuoted:
            return .string(value)
        }
    }

    func composeTaggedScalarValue(
        _ value: String,
        tag: String?,
        mark: PureYAML.Parsing.Mark,
    ) throws -> PureYAML.Model.Value? {
        guard let tag = normalizedTag(tag) else {
            return nil
        }
        switch tag {
        case "tag:yaml.org,2002:str":
            return .string(value)
        case "tag:yaml.org,2002:int":
            guard let int = parseInteger(trim(value)) else {
                throw invalidTaggedScalar(tag: "tag:yaml.org,2002:int", value: value, mark: mark)
            }
            return .int(int)
        case "tag:yaml.org,2002:float":
            guard let double = parseDouble(trim(value)) else {
                throw invalidTaggedScalar(tag: "tag:yaml.org,2002:float", value: value, mark: mark)
            }
            return .double(double)
        case "tag:yaml.org,2002:bool":
            return try composeTaggedBoolValue(value, mark: mark)
        case "tag:yaml.org,2002:null":
            return .null
        default:
            return nil
        }
    }

    func composeTaggedBoolValue(
        _ value: String,
        mark: PureYAML.Parsing.Mark,
    ) throws -> PureYAML.Model.Value {
        guard let bool = parseBool(trim(value)) else {
            throw invalidTaggedScalar(tag: "tag:yaml.org,2002:bool", value: value, mark: mark)
        }
        return .bool(bool)
    }

    func normalizedTag(_ tag: String?) -> String? {
        PureYAML.Parsing.TagNormalizer.normalize(tag)
    }

    func invalidTaggedScalar(
        tag: String,
        value: String,
        mark: PureYAML.Parsing.Mark,
    ) -> PureYAML.Parsing.ParseError {
        PureYAML.Parsing.ParseError.invalidTaggedScalar(
            tag: tag,
            value: value,
            line: mark.line,
            column: mark.column,
        )
    }
}
