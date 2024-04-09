// swift-tools-version: 5.6

import PackageDescription
import Foundation

#if canImport(JavaScriptCore)
let jibSourcePath = "Sources/Jib/JSC"
let jibDependencies: [Target.Dependency] = [
    "CJSCore",
    "Hitch",
    "Chronometer"
]
#else
let jibSourcePath = "Sources/Jib/QuickJS"
let jibDependencies: [Target.Dependency] = [
    "CQuickJS",
    "Hitch",
    "Chronometer"
]
#endif

var jscLibrary = "javascriptcoregtk-4.0"
if FileManager.default.fileExists(atPath: "/usr/include/webkitgtk-4.1") {
    jscLibrary = "javascriptcoregtk-4.1"
}

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
            name: "CJSCore",
            linkerSettings: [
                .linkedLibrary(jscLibrary, .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "CQuickJS"
        ),
        .target(
            name: "Jib",
            dependencies: jibDependencies,
            path: jibSourcePath
        ),
        .testTarget(
            name: "JibTests",
            dependencies: ["Jib"]
        )
    ]
)
