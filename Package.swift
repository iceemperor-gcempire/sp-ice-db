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
        ),
        .library(
            name: "SpIceDBAppModel",
            targets: ["SpIceDBAppModel"]
        ),
        .executable(
            name: "sp-ice-db",
            targets: ["SpIceDBApp"]
        )
    ],
    targets: [
        .target(
            name: "SpIceDBCore"
        ),
        .target(
            name: "SpIceDBAppModel",
            dependencies: ["SpIceDBCore"]
        ),
        .executableTarget(
            name: "SpIceDBApp",
            dependencies: ["SpIceDBCore", "SpIceDBAppModel"]
        ),
        .testTarget(
            name: "SpIceDBCoreTests",
            dependencies: ["SpIceDBCore"]
        ),
        .testTarget(
            name: "SpIceDBAppModelTests",
            dependencies: ["SpIceDBAppModel", "SpIceDBCore"]
        ),
        .testTarget(
            name: "SpIceDBAppBundleTests"
        )
    ]
)
