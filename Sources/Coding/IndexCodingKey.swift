struct IndexCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(index: Int) {
        stringValue = "\(index)"
        intValue = index
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
