// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCardanoCore",
    platforms: [
      .iOS(.v16),
      .macOS(.v14),
      .watchOS(.v8),
      .tvOS(.v15),
      .visionOS(.v1),
      .macCatalyst(.v15),
    ],
    products: [
        .library(
            name: "SwiftCardanoCore",
            targets: ["SwiftCardanoCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.12.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.7.0"),
        .package(url: "https://github.com/Frizlab/swift-fraction-number.git", from: "0.1.0"),
        .package(url: "https://github.com/Kingpin-Apps/swift-base58.git", from: "0.1.4"),
        .package(url: "https://github.com/Kingpin-Apps/swift-cbor-codable.git", .upToNextMinor(from: "0.3.2")),
        .package(url: "https://github.com/Kingpin-Apps/swift-kes.git", .upToNextMinor(from: "1.0.1")),
        .package(url: "https://github.com/Kingpin-Apps/swift-mnemonic.git", .upToNextMinor(from: "0.2.5")),
        .package(url: "https://github.com/Kingpin-Apps/swift-nacl.git", .upToNextMinor(from: "1.0.1")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.9.0")),
        .package(url: "https://github.com/mxcl/Version.git", from: "2.2.0"),
    ],
    targets: [
        .target(
            name: "SwiftCardanoCore",
            dependencies: [
                "BigInt",
                .product(name: "CBORCodable", package: "swift-cbor-codable"),
                "CryptoSwift",
                .product(name: "SwiftMnemonic", package: "swift-mnemonic"),
                .product(name: "SwiftNaCl", package: "swift-nacl"),
                .product(name: "Clibsodium", package: "swift-nacl"),
                .product(name: "SwiftKES", package: "swift-kes"),
                .product(name: "FractionNumber", package: "swift-fraction-number"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Version", package: "version"),
                .product(name: "Crypto", package: "swift-crypto", condition: .when(platforms: [.linux])),
                .product(name: "SwiftBase58", package: "swift-base58"),
            ],
            resources: [
                .embedInCode("Resources/version.json")
            ]
        ),
        .testTarget(
            name: "SwiftCardanoCoreTests",
            dependencies: ["SwiftCardanoCore"],
            resources: [
               .copy("data")
           ]
        ),
    ]
)
