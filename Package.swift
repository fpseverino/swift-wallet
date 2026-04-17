// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "swift-wallet",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "WalletPasses", targets: ["WalletPasses"]),
        .library(name: "WalletOrders", targets: ["WalletOrders"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-asn1.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.4.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.15.1"),
        .package(url: "https://github.com/apple/swift-system.git", from: "1.4.0"),
        .package(url: "https://github.com/adam-fowler/swift-zip-archive.git", from: "0.6.4"),
    ],
    targets: [
        .target(
            name: "WalletPasses",
            dependencies: [
                .product(name: "SwiftASN1", package: "swift-asn1"),
                .product(name: "CryptoExtras", package: "swift-crypto"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "ZipArchive", package: "swift-zip-archive"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "WalletPassesTests",
            dependencies: [
                .target(name: "WalletPasses"),
                .product(name: "SystemPackage", package: "swift-system"),
            ],
            resources: [
                .copy("SourceFiles")
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "WalletOrders",
            dependencies: [
                .product(name: "SwiftASN1", package: "swift-asn1"),
                .product(name: "CryptoExtras", package: "swift-crypto"),
                .product(name: "X509", package: "swift-certificates"),
                .product(name: "ZipArchive", package: "swift-zip-archive"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "WalletOrdersTests",
            dependencies: [
                .target(name: "WalletOrders"),
                .product(name: "SystemPackage", package: "swift-system"),
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
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("ImmutableWeakCaptures"),
    ]
}
