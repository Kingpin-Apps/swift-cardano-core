// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCardanoCore",
    platforms: [
      .iOS(.v14),
      .macOS(.v14),
      .watchOS(.v7),
      .tvOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftCardanoCore",
            targets: ["SwiftCardanoCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/KINGH242/PotentCodables.git", .upToNextMinor(from: "3.6.0")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.9.0")),
        .package(url: "https://github.com/Kingpin-Apps/swift-ncal.git", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/Kingpin-Apps/swift-mnemonic.git", .upToNextMinor(from: "0.2.1")),
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMinor(from: "5.3.0")),
        .package(url: "https://github.com/Frizlab/swift-fraction-number.git", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftCardanoCore",
            dependencies: [
                "BigInt",
                "PotentCodables",
                "CryptoSwift",
                .product(name: "SwiftMnemonic", package: "swift-mnemonic"),
                .product(name: "SwiftNcal", package: "swift-ncal"),
                .product(name: "Clibsodium", package: "swift-ncal"),
                .product(name: "FractionNumber", package: "swift-fraction-number"),
                .product(name: "Logging", package: "swift-log")
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
