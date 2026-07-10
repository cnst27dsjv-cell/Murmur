// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MurmurApp",
            path: "Sources/MurmurApp"
        )
    ]
)
