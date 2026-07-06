// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CribbageData",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(name: "CribbageData", targets: ["CribbageData"])
    ],
    dependencies: [
        .package(path: "../CribbageKit"),
        .package(path: "../CribbageBoardKit"),
    ],
    targets: [
        .target(name: "CribbageData", dependencies: ["CribbageKit", "CribbageBoardKit"]),
        .testTarget(name: "CribbageDataTests", dependencies: ["CribbageData"]),
    ]
)
