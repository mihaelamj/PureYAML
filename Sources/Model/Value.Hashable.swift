public extension PureYAML.Model.Value {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            true
        case let (.bool(lhs), .bool(rhs)):
            lhs == rhs
        case let (.double(lhs), .double(rhs)):
            lhs == rhs || (lhs.isNaN && rhs.isNaN)
        case let (.int(lhs), .int(rhs)):
            lhs == rhs
        case let (.mapping(lhs), .mapping(rhs)):
            lhs == rhs
        case let (.sequence(lhs), .sequence(rhs)):
            lhs == rhs
        case let (.string(lhs), .string(rhs)):
            lhs == rhs
        default:
            false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case let .bool(value):
            hasher.combine(1)
            hasher.combine(value)
        case let .double(value):
            hasher.combine(2)
            if value.isNaN {
                hasher.combine("nan")
            } else {
                hasher.combine(value)
            }
        case let .int(value):
            hasher.combine(3)
            hasher.combine(value)
        case let .mapping(value):
            hasher.combine(4)
            hasher.combine(value)
        case let .sequence(value):
            hasher.combine(5)
            hasher.combine(value)
        case let .string(value):
            hasher.combine(6)
            hasher.combine(value)
        }
    }
}
