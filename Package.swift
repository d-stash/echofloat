// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "echofloat",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "echofloat"),
        .testTarget(name: "echofloatTests", dependencies: ["echofloat"]),
    ]
)
