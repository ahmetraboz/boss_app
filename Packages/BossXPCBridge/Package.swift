// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BossXPCBridge",
    platforms: [
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "BossXPCBridge",
            targets: ["BossXPCBridge"]
        ),
    ],
    targets: [
        .target(
            name: "BossXPCBridge",
            path: "Sources/BossXPCBridge",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
