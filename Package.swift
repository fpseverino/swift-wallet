// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-wallet",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "Passes", targets: ["Passes"]),
        .library(name: "Orders", targets: ["Orders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.6.1"),
        .package(url: "https://github.com/vapor-community/Zip.git", from: "2.2.4"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Passes",
            dependencies: [
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "Zip", package: "zip"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "PassesTests",
            dependencies: [
                .target(name: "Passes")
            ],
            resources: [
                .copy("SourceFiles")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "Orders",
            dependencies: [
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "Zip", package: "zip"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "OrdersTests",
            dependencies: [
                .target(name: "Orders")
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
