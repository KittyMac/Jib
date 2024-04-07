// swift-tools-version: 5.6

import PackageDescription
import Foundation

let package = Package(
    name: "Jib",
    platforms: [
        .macOS(.v10_13), .iOS(.v11)
    ],
    products: [
        .library( name: "Jib", targets: ["Jib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Chronometer.git", from: "0.1.0"),
        .package(url: "https://github.com/KittyMac/Hitch.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "QuickJS"
        ),
        .target(
            name: "Jib",
            dependencies: [
                "QuickJS",
                "Hitch",
                "Chronometer"
            ]
        ),
        .testTarget(
            name: "JibTests",
            dependencies: ["Jib"]
        )
    ]
)
