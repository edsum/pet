// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeskPetKit",
    platforms: [
        .iOS(.v18),         // 需要 iOS 18.2+ 才有 Image Playground，最小部署写 .v18
        .macOS(.v13),       // 仅用于在 Mac 上跑 swift test，App 本身不跑在 Mac 上
    ],
    products: [
        .library(name: "DeskPetKit", targets: ["DeskPetKit"]),
    ],
    targets: [
        .target(
            name: "DeskPetKit",
            path: "Sources/DeskPetKit",
            swiftSettings: [
                // ★ 用 Swift 5 语言模式，避免 strict concurrency 把 ActivityKit 的
                // nonisolated async API 报成"data races"错误。
                // 工程层面用 SWIFT_STRICT_CONCURRENCY=minimal 控制。
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "DeskPetKitTests",
            dependencies: ["DeskPetKit"],
            path: "Tests/DeskPetKitTests"
        ),
    ]
)
