// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CribbageKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(name: "CribbageKit", targets: ["CribbageKit"])
    ],
    targets: [
        .target(name: "CribbageKit"),
        .testTarget(name: "CribbageKitTests", dependencies: ["CribbageKit"]),
    ]
)
