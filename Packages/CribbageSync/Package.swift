// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CribbageSync",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: "CribbageSync", targets: ["CribbageSync"])
    ],
    dependencies: [
        .package(path: "../CribbageKit")
    ],
    targets: [
        .target(name: "CribbageSync", dependencies: ["CribbageKit"]),
        .testTarget(name: "CribbageSyncTests", dependencies: ["CribbageSync"])
    ]
)
