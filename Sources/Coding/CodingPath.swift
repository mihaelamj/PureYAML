extension PureYAML.Validation.Path {
    init(codingPath: [any CodingKey]) {
        self.init(codingPath.map { key in
            if let index = key.intValue {
                return .index(index)
            }
            return .key(key.stringValue)
        })
    }
}
