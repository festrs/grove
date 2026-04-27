// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GroveCore",
    platforms: [
        .iOS("26.0"),
        .macOS("15.0"),
    ],
    products: [
        .library(name: "GroveDomain", targets: ["GroveDomain"]),
        .library(name: "GroveServices", targets: ["GroveServices"]),
        .library(name: "GroveRepositories", targets: ["GroveRepositories"]),
    ],
    targets: [
        .target(name: "GroveDomain"),
        .target(name: "GroveServices", dependencies: ["GroveDomain"]),
        .target(
            name: "GroveRepositories",
            dependencies: ["GroveDomain", "GroveServices"]
        ),
        .testTarget(
            name: "GroveCoreTests",
            dependencies: ["GroveDomain", "GroveServices", "GroveRepositories"]
        ),
    ]
)
