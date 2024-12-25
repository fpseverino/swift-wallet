// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-wallet",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "WalletPasses", targets: ["WalletPasses"]),
        .library(name: "WalletOrders", targets: ["WalletOrders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.6.1"),
        .package(url: "https://github.com/vapor-community/Zip.git", from: "2.2.4"),
    ],
    targets: [
        .target(
            name: "WalletPasses",
            dependencies: [
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "Zip", package: "zip"),
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
                .product(name: "Zip", package: "zip"),
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
