extension PureYAML.Parsing.Parser {
    func trim(_ text: String) -> String {
        var start = text.startIndex
        var end = text.endIndex
        while start < end, text[start].isWhitespace {
            start = text.index(after: start)
        }
        while end > start {
            let previous = text.index(before: end)
            if !text[previous].isWhitespace {
                break
            }
            end = previous
        }
        return String(text[start ..< end])
    }
}
