// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "sp-ice-db",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SpIceDBCore",
            targets: ["SpIceDBCore"]
        )
    ],
    targets: [
        .target(
            name: "SpIceDBCore"
        ),
        .testTarget(
            name: "SpIceDBCoreTests",
            dependencies: ["SpIceDBCore"]
        )
    ]
)

