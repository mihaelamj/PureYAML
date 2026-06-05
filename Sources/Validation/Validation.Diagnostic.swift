public extension PureYAML.Validation {
    enum DiagnosticKind: Equatable, Sendable, CustomStringConvertible {
        case parse
        case validation

        public var description: String {
            switch self {
            case .parse:
                "parse"
            case .validation:
                "validation"
            }
        }
    }

    /// A parse or validation diagnostic suitable for batch validation reports.
    struct Diagnostic: Equatable, Sendable, CustomStringConvertible {
        public var kind: DiagnosticKind
        public var severity: Severity
        public var file: String?
        public var line: Int?
        public var column: Int?
        public var documentIndex: Int?
        public var path: Path?
        public var reason: String

        public init(
            kind: DiagnosticKind,
            severity: Severity,
            file: String? = nil,
            line: Int? = nil,
            column: Int? = nil,
            documentIndex: Int? = nil,
            path: Path? = nil,
            reason: String,
        ) {
            self.kind = kind
            self.severity = severity
            self.file = file
            self.line = line
            self.column = column
            self.documentIndex = documentIndex
            self.path = path
            self.reason = reason
        }

        public var description: String {
            var parts: [String] = []
            if let file {
                parts.append(file)
            }
            if let line, let column {
                parts.append("line \(line), column \(column)")
            } else if let line {
                parts.append("line \(line)")
            } else if let column {
                parts.append("column \(column)")
            }
            if let documentIndex {
                parts.append("document[\(documentIndex)]")
            }
            if let path {
                parts.append(path.isRoot ? "root" : path.description)
            }
            let location = parts.isEmpty ? "input" : parts.joined(separator: ": ")
            return "\(location): \(severity): \(kind): \(reason)"
        }
    }
}
