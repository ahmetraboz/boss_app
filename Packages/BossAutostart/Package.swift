// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BossAutostart",
    platforms: [
        .macOS(.v13),
        .macCatalyst(.v16),
    ],
    products: [
        .library(
            name: "BossAutostart",
            targets: ["BossAutostart"]
        ),
    ],
    targets: [
        .target(
            name: "BossAutostart",
            path: "BossAutostart"
        ),
    ]
)
