// swift-tools-version:5.9
//
// Touch Bar Rainbow - a flowing rainbow on the MacBook Pro Touch Bar while PyCharm is active.
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

import PackageDescription

var products: [Product] = [
    .library(name: "RainbowCore", targets: ["RainbowCore"]),
    .executable(name: "rainbow-preview", targets: ["rainbow-preview"]),
]

var targets: [Target] = [
    .target(name: "RainbowCore"),
    .executableTarget(name: "rainbow-preview", dependencies: ["RainbowCore"]),
    .testTarget(name: "RainbowCoreTests", dependencies: ["RainbowCore"]),
]

#if os(macOS)
products.append(.executable(name: "TouchBarRainbow", targets: ["TouchBarRainbow"]))
targets += [
    .target(
        name: "TouchBarPrivate",
        linkerSettings: [.linkedFramework("AppKit")]
    ),
    .executableTarget(
        name: "TouchBarRainbow",
        dependencies: ["RainbowCore", "TouchBarPrivate"],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("QuartzCore"),
            .linkedFramework("ServiceManagement"),
            .linkedFramework("ApplicationServices"),
        ]
    ),
]
#endif

let package = Package(
    name: "TouchBarRainbow",
    platforms: [.macOS(.v11)],
    products: products,
    targets: targets
)
