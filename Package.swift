// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Server",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Server",
            targets: ["Server"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-webc/HTTP.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Cryptography.git", branch: "master"),

        .package(url: "https://github.com/swift-lco/Milieu.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Loggers.git", branch: "master"),

        .package(url: "https://github.com/swift-lco/Variables.git", branch: "master"),
        .package(url: "https://github.com/swift-lco/Primitives.git", branch: "master"),

        .package(url: "https://github.com/swift-langs/Parsers.git", branch: "master"),

        .package(url: "https://github.com/swift-lco/Path.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "Server",
            dependencies: [
                .product(name: "HTTP", package: "HTTP"),
                .product(name: "Cryptography", package: "Cryptography"),

                .product(name: "Milieu", package: "Milieu"),
                .product(name: "Loggers", package: "Loggers"),

                .product(name: "Variables", package: "Variables"),
                .product(name: "Primitives", package: "Primitives"),

                .product(name: "Parsers", package: "Parsers"),

                .product(name: "Path", package: "Path"),
            ]
        ),
    ]
)
