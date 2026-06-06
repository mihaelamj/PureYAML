extension PureYAML.Parsing {
    enum ScannerFlowContextKind {
        case sequence
        case mapping
    }

    struct ScannerFlowContext {
        var kind: ScannerFlowContextKind
        var isExpectingKey: Bool
    }
}
