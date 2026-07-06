// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CribbageVision",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "CribbageVision", targets: ["CribbageVision"])
    ],
    dependencies: [
        .package(path: "../CribbageKit")
    ],
    targets: [
        .target(name: "CribbageVision", dependencies: ["CribbageKit"]),
        .testTarget(name: "CribbageVisionTests", dependencies: ["CribbageVision"]),
    ]
)
