// swift-tools-version: 5.9
// MotionPlayground — Anycast iOS 26 SwiftUI 动效交互示例集
// 在 Xcode 26 中 Open 此文件即可，每个 Chapter*.swift 内的 #Preview 在 Canvas 实时渲染。
import PackageDescription

let package = Package(
    name: "MotionPlayground",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MotionPlayground", targets: ["MotionPlayground"]),
    ],
    targets: [
        .target(
            name: "MotionPlayground",
            path: "Sources/MotionPlayground",
            resources: [.process("Resources")]
        ),
    ]
)
