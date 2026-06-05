extension PureYAML.Parsing.Parser {
    func parseEvents(_ yaml: String) throws -> [PureYAML.Parsing.Event] {
        let tokens = try PureYAML.Parsing.Scanner().scan(yaml)
        var parser = PureYAML.Parsing.TokenEventParser(tokens: tokens, scalarParser: self)
        return try parser.parse()
    }
}
