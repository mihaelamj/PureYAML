public extension PureYAML.Emitting.Dumper {
    /// Serializes indexed YAML stream documents with explicit document starts.
    func dump(_ documents: [PureYAML.Stream.Document]) -> String {
        documents
            .map { document in
                "---\n" + dump(document.value)
            }
            .joined()
    }
}
