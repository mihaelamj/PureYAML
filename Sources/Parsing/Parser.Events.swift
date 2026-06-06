extension PureYAML.Parsing.Parser {
    func parseEvents(_ yaml: String) throws -> [PureYAML.Parsing.Event] {
        let tokens = try PureYAML.Parsing.Scanner().scan(yaml)
        var parser = PureYAML.Parsing.TokenEventParser(tokens: tokens, scalarParser: self)
        return try parser.parse()
    }

    func parseStreaming(_ yaml: String) throws -> PureYAML.Model.Value {
        var composer = PureYAML.Parsing.EventStreamComposer(
            scalarParser: self,
            mode: .singleDocument,
        )
        var parser = PureYAML.Parsing.TokenEventParser(
            yaml: yaml,
            scalarParser: self,
            eventSink: { event in
                try composer.consume(event)
            },
        )
        try parser.parseStreaming()
        return try composer.composedValue()
    }

    func parseStreamStreaming(_ yaml: String) throws -> [PureYAML.Stream.Document] {
        var composer = PureYAML.Parsing.EventStreamComposer(
            scalarParser: self,
            mode: .stream,
        )
        var parser = PureYAML.Parsing.TokenEventParser(
            yaml: yaml,
            scalarParser: self,
            eventSink: { event in
                try composer.consume(event)
            },
        )
        try parser.parseStreaming()
        return try composer.composedStream()
    }
}
