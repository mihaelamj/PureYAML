extension PureYAML.Parsing {
    struct EventState {
        var lines: [Line]
        var index: Int
        var events: [Event]
    }
}
