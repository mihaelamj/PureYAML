public extension PureYAML {
    /// Parses a YAML document into a ``Model/Value`` tree.
    static func parse(_ yaml: String) throws -> Model.Value {
        try Parsing.Parser().parse(yaml)
    }

    /// Serializes a ``Model/Value`` tree into YAML with the selected options.
    static func dump(
        _ value: Model.Value,
        options: Emitting.Options = .default,
    ) -> String {
        Emitting.Dumper(options: options).dump(value)
    }

    /// Validates a parsed YAML value with the default validation rules.
    @discardableResult
    static func validate(
        _ value: Model.Value,
        using validator: Validation.Validator = .init(),
        strict: Bool = true,
    ) throws -> [Validation.Issue] {
        try validator.validate(value, strict: strict)
    }
}
