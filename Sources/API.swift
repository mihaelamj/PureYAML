public extension PureYAML {
    /// Parses a YAML document into a ``Model/Value`` tree.
    static func parse(_ yaml: String) throws -> Model.Value {
        try Parsing.Parser().parse(yaml)
    }

    /// Parses a YAML stream into indexed documents.
    static func parseStream(_ yaml: String) throws -> [Stream.Document] {
        try Parsing.Parser().parseStream(yaml)
    }

    /// Serializes a ``Model/Value`` tree into YAML with the selected options.
    static func dump(
        _ value: Model.Value,
        options: Emitting.Options = .default,
    ) -> String {
        Emitting.Dumper(options: options).dump(value)
    }

    /// Serializes indexed YAML stream documents with explicit document starts.
    static func dump(
        _ documents: [Stream.Document],
        options: Emitting.Options = .default,
    ) -> String {
        Emitting.Dumper(options: options).dump(documents)
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

    /// Validates parsed YAML stream documents while preserving document indexes.
    @discardableResult
    static func validate(
        _ documents: [Stream.Document],
        using validator: Validation.Validator = .init(),
        strict: Bool = true,
    ) throws -> [Stream.Issue] {
        try validator.validate(documents, strict: strict)
    }

    /// Decodes a typed value from a YAML value tree.
    static func decode<Value: Decodable>(
        _: Value.Type = Value.self,
        from value: Model.Value,
    ) throws -> Value {
        try validate(value)
        return try Value(from: Decoding.Decoder(value: value, validatesInput: false))
    }

    /// Parses YAML and decodes a typed value from the resulting value tree.
    static func decode<Value: Decodable>(
        _ type: Value.Type = Value.self,
        from yaml: String,
    ) throws -> Value {
        try decode(type, from: parse(yaml))
    }

    /// Encodes a typed value into a YAML value tree.
    static func encode<Value: Encodable>(_ value: Value) throws -> Model.Value {
        let encoder = Encoding.Encoder()
        try value.encode(to: encoder)
        return try encoder.encodedValue()
    }

    /// Encodes a typed value and serializes the resulting value tree as YAML.
    static func encodeToYAML(
        _ value: some Encodable,
        options: Emitting.Options = .default,
    ) throws -> String {
        try dump(encode(value), options: options)
    }
}
