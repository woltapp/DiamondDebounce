// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DiamondDebounce",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "DiamondDebounce",
            targets: ["DiamondDebounce"]
        ),
    ],
    dependencies: [
        .package(path: "../Locked")
    ],
    targets: [
        .target(
            name: "DiamondDebounce",
            dependencies: [
                "Locked"
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"])
            ]
        ),
        .testTarget(
            name: "DiamondDebounceTests",
            dependencies: [
                "DiamondDebounce"
            ]
        )
    ]
)
