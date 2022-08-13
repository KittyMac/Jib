// swift-tools-version: 5.6

import PackageDescription

#if canImport(JavaScriptCore)
let jibTargets: [Target] = [
    .target(
        name: "Jib",
        dependencies: [
            "Hitch",
            "Spanker",
            "Chronometer"
        ]
    )
]
#else
let jibTargets: [Target] = [
    .target(
        name: "CJSCore",
        linkerSettings: [
            .linkedLibrary("javascriptcoregtk-4.0", .when(platforms: [.linux])),
        ]
    ),
    .target(
        name: "Jib",
        dependencies: [
            "CJSCore",
            "Hitch",
            "Spanker",
            "Chronometer"
        ]
    ),
]
#endif

let package = Package(
    name: "Jib",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library( name: "Jib", targets: ["Jib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Chronometer.git", from: "0.1.0"),
        .package(url: "https://github.com/KittyMac/Hitch.git", from: "0.4.0"),
        .package(url: "https://github.com/KittyMac/Spanker.git", from: "0.2.0"),
    ],
    targets: jibTargets + [
        .testTarget(
            name: "JibTests",
            dependencies: ["Jib"]
        )
    ]
)
