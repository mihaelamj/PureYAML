public extension PureYAML.Validation {
    /// Error that carries the structured validation report for failed input.
    struct ReportError: Swift.Error, Equatable, Sendable, CustomStringConvertible {
        public var report: Report

        public init(report: Report) {
            self.report = report
        }

        public var description: String {
            report.description
        }
    }
}
