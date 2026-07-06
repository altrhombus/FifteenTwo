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
        .package(path: "../CribbageSync"),
        .package(path: "../CribbageVision")
    ],
    targets: [
        .target(
            name: "CribbageUI",
            dependencies: [
                "CribbageKit", "CribbageBoardKit", "CribbageData", "CribbageSync",
                // CribbageVision only declares iOS/macOS platform support (no camera-based
                // hand-scanning story on watchOS), so this must be a conditional
                // dependency, not an unconditional one — otherwise resolving CribbageUI
                // for watchOS (the embedded Watch target pulls in the whole package)
                // fails before any #if os(watchOS) guard in the source even runs.
                .product(name: "CribbageVision", package: "CribbageVision", condition: .when(platforms: [.iOS, .macOS]))
            ]
        ),
        .testTarget(name: "CribbageUITests", dependencies: ["CribbageUI"])
    ]
)
