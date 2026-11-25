// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ServerTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "servtest",
            targets: ["ServerTestFlows"]
        ),
        .executable(
            name: "servlive",
            targets: ["ServerLiveTest"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-webc/HTTP.git", branch: "master"),
        .package(url: "https://github.com/swift-tooling/TestFlows.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Processes.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "ServerTestFlows",
            dependencies: [
                .product(name: "Server", package: "Server"),
                "HTTP",
                "TestFlows",
                .product(
                    name: "Processes",
                    package: "Processes"
                ),
                .product(
                    name: "TestFlowsProcesses",
                    package: "Processes"
                ),
            ]
        ),
        .executableTarget(
            name: "ServerLiveTest",
            dependencies: [
                .product(name: "Server", package: "Server"),
                "HTTP",
            ]
        ),
    ]
)
