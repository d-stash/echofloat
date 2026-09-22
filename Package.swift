// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "echofloat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "echofloat", targets: ["echofloat"]),
    ],
    targets: [
        .executableTarget(name: "echofloat"),
    ]
)
