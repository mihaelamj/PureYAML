extension PureYAML.Parsing {
    enum TagNormalizer {
        static let shorthandTags: [String: String] = [
            "!!str": "tag:yaml.org,2002:str",
            "!!seq": "tag:yaml.org,2002:seq",
            "!!map": "tag:yaml.org,2002:map",
            "!!bool": "tag:yaml.org,2002:bool",
            "!!float": "tag:yaml.org,2002:float",
            "!!null": "tag:yaml.org,2002:null",
            "!!int": "tag:yaml.org,2002:int",
            "!!binary": "tag:yaml.org,2002:binary",
            "!!merge": "tag:yaml.org,2002:merge",
            "!!omap": "tag:yaml.org,2002:omap",
            "!!pairs": "tag:yaml.org,2002:pairs",
            "!!set": "tag:yaml.org,2002:set",
            "!!timestamp": "tag:yaml.org,2002:timestamp",
            "!!value": "tag:yaml.org,2002:value",
            "!!yaml": "tag:yaml.org,2002:yaml",
        ]

        static func normalize(_ tag: String?) -> String? {
            guard let tag else {
                return nil
            }
            if tag.hasPrefix("!<"), tag.hasSuffix(">") {
                return String(tag.dropFirst(2).dropLast())
            }
            return shorthandTags[tag] ?? tag
        }
    }
}
