// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-wallet",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "WalletPasses", targets: ["WalletPasses"]),
        .library(name: "WalletOrders", targets: ["WalletOrders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.6.1"),
        .package(url: "https://github.com/adam-fowler/swift-zip-archive.git", from: "0.4.1"),
    ],
    targets: [
        .target(
            name: "WalletPasses",
            dependencies: [
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "ZipArchive", package: "swift-zip-archive"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "WalletPassesTests",
            dependencies: [
                .target(name: "WalletPasses")
            ],
            resources: [
                .copy("SourceFiles")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "WalletOrders",
            dependencies: [
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "ZipArchive", package: "swift-zip-archive"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "WalletOrdersTests",
            dependencies: [
                .target(name: "WalletOrders")
            ],
            resources: [
                .copy("SourceFiles")
            ],
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [SwiftSetting] {
    [
        .enableUpcomingFeature("ExistentialAny")
    ]
}
