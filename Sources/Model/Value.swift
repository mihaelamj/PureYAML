public extension PureYAML.Model {
    /// Lossless-enough YAML value tree for the first parser milestone.
    enum Value: Equatable, Sendable {
        case null
        case bool(Bool)
        case int(Int)
        case double(Double)
        case string(String)
        case sequence([Value])
        case mapping(Mapping)
    }
}
