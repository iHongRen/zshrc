// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ZshrcEditor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ZshrcEditor",
            targets: ["ZshrcEditor"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ZshrcEditor",
            path: "Sources/ZshrcEditor"
        )
    ]
)
