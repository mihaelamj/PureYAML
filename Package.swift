// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "PureYAML",
    products: [
        .library(
            name: "PureYAML",
            targets: ["PureYAML"],
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PureYAML",
            path: "Sources",
        ),
        .testTarget(
            name: "PureYAMLTests",
            dependencies: ["PureYAML"],
            path: "Tests",
        ),
    ],
)
