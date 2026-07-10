// swift-tools-version: 6.2
import PackageDescription

let concurrencyBaseline: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(nil),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "AppRouter",
    platforms: [ .iOS(.v17) ],
    products: [ .library(name: "AnvyxRouterKit", targets: ["AnvyxRouterKit"]) ],
    targets: [
        .target(name: "AnvyxRouterKit", swiftSettings: concurrencyBaseline),
        .testTarget(name: "AnvyxRouterKitTests", dependencies: ["AnvyxRouterKit"], swiftSettings: concurrencyBaseline),
    ]
)
