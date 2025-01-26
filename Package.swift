// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Gaabi",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Gaabi",
            targets: ["Gaabi"]
        ),
    ],
    dependencies: [
        .package(path: "Packages/TaskManager"),
        .package(path: "Packages/LocationManager"),
        .package(path: "Packages/VoiceManager"),
        .package(path: "Packages/AIManager"),
        .package(path: "Packages/SmartHomeManager")
    ],
    targets: [
        .target(
            name: "Gaabi",
            dependencies: [
                .product(name: "TaskManager", package: "TaskManager"),
                .product(name: "LocationManager", package: "LocationManager"),
                .product(name: "VoiceManager", package: "VoiceManager"),
                .product(name: "AIManager", package: "AIManager"),
                .product(name: "SmartHomeManager", package: "SmartHomeManager")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "GaabiTests",
            dependencies: ["Gaabi"]
        ),
    ]
) 