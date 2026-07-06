// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CribbageKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: "CribbageKit", targets: ["CribbageKit"])
    ],
    targets: [
        .target(
            name: "CribbageKit",
            // The solvers run ~684,000 Scorer calls per discard analysis — fast in a
            // release build (~1.3s) but ~22s unoptimized, which reads as a hang during
            // ordinary Xcode debug runs. Forcing optimization here (this package has no
            // interactive debugging needs beyond its own thorough unit test suite) keeps
            // CPU moves responsive without requiring a full release build of the app.
            swiftSettings: [.unsafeFlags(["-Ounchecked"], .when(configuration: .debug))]
        ),
        .testTarget(name: "CribbageKitTests", dependencies: ["CribbageKit"])
    ]
)
