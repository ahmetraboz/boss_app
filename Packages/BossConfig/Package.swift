// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BossConfig",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .tvOS(.v14),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "BossConfig",
            targets: ["BossConfig"]
        ),
    ],
    targets: [
        .target(
            name: "BossConfig",
            path: "BossConfig",
            resources: [
                .copy("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
