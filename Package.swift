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
        .package(url: "https://github.com/leviouwendijk/HTTP.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Cryptography.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/Milieu.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Loggers.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/Variables.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),

        .package(url: "https://github.com/leviouwendijk/Parsers.git", branch: "master"),
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
            ]
        ),
        .testTarget(
            name: "ServerTests",
            dependencies: ["Server"]
        ),
    ]
)
