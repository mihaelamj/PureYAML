# Attribution

PureYAML is an independent Swift implementation.

This project is informed by the behavior and public API surface of
[Yams](https://github.com/jpsim/Yams), and by the YAML parsing model embodied in
Yams' bundled `CYaml` / libyaml-derived C sources. Yams is an important Swift YAML
package, and its behavior is a compatibility reference for PureYAML.

PureYAML does not copy Yams Swift source code, `CYaml` C source code, or libyaml
C source code into the public package. The implementation under `Sources/` is
written in Swift for this repository.

Yams and libyaml source remain available from their upstream projects:

- https://github.com/jpsim/Yams
- https://pyyaml.org/wiki/LibYAML

The license file includes a matching attribution notice.

The private `PureYAMLResearch` repository contains a full Yams source snapshot
for study and compatibility research. That repository is not the implementation
source for PureYAML.
