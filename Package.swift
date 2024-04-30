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
        .package(url: "https://github.com/woltapp/Locked", exact: "0.1.0"),
    ],
    targets: [
        .target(
            name: "DiamondDebounce",
            dependencies: [
                "Locked"
            ],
            swiftSettings: [
			    .enableExperimentalFeature("StrictConcurrency")
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
