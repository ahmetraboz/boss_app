// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BossWindowBridge",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "BossWindowBridge",
            targets: ["BossWindowBridge"]
        ),
    ],
    targets: [
        .target(
            name: "BossWindowBridge",
            path: "Sources/BossWindowBridge"
        ),
    ]
)
