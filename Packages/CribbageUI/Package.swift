// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CribbageUI",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: "CribbageUI", targets: ["CribbageUI"])
    ],
    dependencies: [
        .package(path: "../CribbageKit"),
        .package(path: "../CribbageBoardKit"),
        .package(path: "../CribbageData"),
        .package(path: "../CribbageSync")
    ],
    targets: [
        .target(name: "CribbageUI", dependencies: ["CribbageKit", "CribbageBoardKit", "CribbageData", "CribbageSync"]),
        .testTarget(name: "CribbageUITests", dependencies: ["CribbageUI"])
    ]
)
