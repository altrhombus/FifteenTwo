// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CribbageBoardKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: "CribbageBoardKit", targets: ["CribbageBoardKit"])
    ],
    dependencies: [
        .package(path: "../CribbageKit")
    ],
    targets: [
        .target(name: "CribbageBoardKit", dependencies: ["CribbageKit"]),
        .testTarget(name: "CribbageBoardKitTests", dependencies: ["CribbageBoardKit"])
    ]
)
