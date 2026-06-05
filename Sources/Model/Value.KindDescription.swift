extension PureYAML.Model.Value {
    var kindDescription: String {
        switch self {
        case .null:
            "null"
        case .bool:
            "bool"
        case .int:
            "int"
        case .double:
            "double"
        case .string:
            "string"
        case .sequence:
            "sequence"
        case .mapping:
            "mapping"
        }
    }
}
