// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ShareGatherFeature",
    platforms: [.iOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ShareGatherFeature",
            targets: ["ShareGatherFeature"]
        ),
        .library(
            name: "ShareGatherStorage",
            targets: ["ShareGatherStorage"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ShareGatherStorage",
            resources: [.process("Resources")]
        ),
        .target(
            name: "ShareGatherFeature",
            dependencies: ["ShareGatherStorage"]
        ),
        .testTarget(
            name: "ShareGatherFeatureTests",
            dependencies: [
                "ShareGatherFeature",
                "ShareGatherStorage"
            ]
        ),
    ]
)
