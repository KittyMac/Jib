// swift-tools-version: 5.6

import PackageDescription

#if canImport(JavaScriptCore)
let jibTargets: [Target] = [
    .target(
        name: "JibFramework",
        dependencies: [
            "Hitch"
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
        name: "JibFramework",
        dependencies: [
            "CJSCore",
            "Hitch"
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
        .library( name: "JibFramework", targets: ["JibFramework"]),
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Hitch.git", from: "0.4.0"),
    ],
    targets: jibTargets + [
        .testTarget(
            name: "JibTests",
            dependencies: ["JibFramework"]
        )
    ]
)
