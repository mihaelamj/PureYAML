@testable import PureYAML

extension PureYAML.Model.Value {
    var rootMapping: PureYAML.Model.Mapping? {
        guard case let .mapping(mapping) = self else {
            return nil
        }
        return mapping
    }
}
