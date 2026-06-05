struct SuperCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init() {
        stringValue = "super"
        intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue _: Int) {
        nil
    }
}
