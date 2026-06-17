// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "slop",
    platforms: [.macOS("26.0")],
    targets: [
        .executableTarget(name: "slop"),
        .testTarget(name: "slopTests", dependencies: ["slop"]),
    ]
)
