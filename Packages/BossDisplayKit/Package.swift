// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "BossDisplayKit",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "BossDisplayKit",
            targets: ["BossDisplayKit"]
        ),
    ],
    targets: [
        .target(
            name: "BossDisplayKit"
        ),
    ]
)
