// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "echofloat",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "echofloat", targets: ["echofloat"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            exact: "6.2.4"
        ),
    ],
    targets: [
        .executableTarget(
            name: "echofloat",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "echofloatTests",
            dependencies: [
                "echofloat",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
