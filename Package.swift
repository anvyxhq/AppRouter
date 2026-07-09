// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppRouter",
    platforms: [ .iOS(.v17) ],
    products: [ .library(name: "AnvyxRouterKit", targets: ["AnvyxRouterKit"]) ],
    targets: [
        .target(name: "AnvyxRouterKit"),
        .testTarget(name: "AnvyxRouterKitTests", dependencies: ["AnvyxRouterKit"]),
    ]
)
