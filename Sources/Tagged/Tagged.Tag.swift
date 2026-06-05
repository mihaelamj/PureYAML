public extension PureYAML.Tagged {
    /// YAML tag preserved from the source document.
    struct Tag: Equatable, Hashable, Sendable, CustomStringConvertible {
        public var rawValue: String

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        public var description: String {
            rawValue
        }

        public var isBuiltIn: Bool {
            rawValue.hasPrefix("tag:yaml.org,2002:")
        }
    }
}

public extension PureYAML.Tagged.Tag {
    static let string = Self("tag:yaml.org,2002:str")
    static let sequence = Self("tag:yaml.org,2002:seq")
    static let mapping = Self("tag:yaml.org,2002:map")
    static let bool = Self("tag:yaml.org,2002:bool")
    static let float = Self("tag:yaml.org,2002:float")
    static let null = Self("tag:yaml.org,2002:null")
    static let int = Self("tag:yaml.org,2002:int")
    static let binary = Self("tag:yaml.org,2002:binary")
    static let merge = Self("tag:yaml.org,2002:merge")
    static let orderedMap = Self("tag:yaml.org,2002:omap")
    static let pairs = Self("tag:yaml.org,2002:pairs")
    static let set = Self("tag:yaml.org,2002:set")
    static let timestamp = Self("tag:yaml.org,2002:timestamp")
    static let value = Self("tag:yaml.org,2002:value")
    static let yaml = Self("tag:yaml.org,2002:yaml")
}

extension PureYAML.Tagged.Tag {
    static func normalized(_ tag: String?) -> Self? {
        PureYAML.Parsing.TagNormalizer.normalize(tag).map(Self.init)
    }

    var expectedKind: PureYAML.Tagged.NodeKind? {
        switch self {
        case .string, .bool, .float, .null, .int, .binary, .merge, .timestamp, .value, .yaml:
            .scalar
        case .sequence, .orderedMap, .pairs:
            .sequence
        case .mapping, .set:
            .mapping
        default:
            nil
        }
    }

    var isSupportedBuiltInTag: Bool {
        switch self {
        case .string, .sequence, .mapping, .bool, .float, .null, .int:
            true
        default:
            false
        }
    }
}
