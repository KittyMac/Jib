// swift-tools-version: 5.6

import PackageDescription
import Foundation

// By default, Jib will use JavascriptCore on platforms it is easily
// available (ie all but Windows). If you would like to force a specific
// engine, then set the appropriate environment variable
// setenv("JIB", "JSC", 1)
// setenv("JIB", "QJS", 1)

var engine: String? = ProcessInfo.processInfo.environment["JIB"]

if engine == nil {
#if os(Windows)
    engine = "JSC"
#else
    engine = "JSC"
#endif
}

var jibSourcePath = "Sources/Unknown"
var jibDependencies: [Target.Dependency] = []
var dynamicLibrary: [Product] = []
var linkedLibrary: [LinkerSetting] = []

if engine == "JSC" {
    jibSourcePath = "Sources/Jib/JSC"
    #if !canImport(JavaScriptCore)
    jibDependencies = [ "CJSCore" ]
    #endif
    jibDependencies += [
        "Hitch",
        "Chronometer"
    ]
    #if os(Linux)
    if FileManager.default.fileExists(atPath: "/usr/include/webkitgtk-4.0") {
        linkedLibrary = ["javascriptcoregtk-4.0"]
    } else if FileManager.default.fileExists(atPath: "/usr/include/webkitgtk-4.1") {
        linkedLibrary = ["javascriptcoregtk-4.1"]
    }
    #endif
    #if os(Windows)
    let sdkRoot: String = ProcessInfo.processInfo.environment["SDKROOT"]!
    linkedLibrary = [
        .linkedLibrary("DLL/JavaScriptCore", .when(platforms: [.windows])),
        .linkedLibrary("\(sdkRoot)usr\\lib\\swift\\windows\\x86_64\\swiftCore", .when(platforms: [.windows]))
    ]
    #endif
}

if engine == "QJS" {
    jibSourcePath = "Sources/Jib/QuickJS"
    jibDependencies = [
        "CQuickJS",
        "Hitch",
        "Chronometer"
    ]
    #if os(Linux) || os(Android) || os(Windows)
    dynamicLibrary = [
        .library( name: "CQuickJSLib", type: .dynamic, targets: ["CQuickJS"])
    ]
    #endif
    #if os(Windows)
    let sdkRoot: String = ProcessInfo.processInfo.environment["SDKROOT"]!
    linkedLibrary = [
        .linkedLibrary("\(sdkRoot)usr\\lib\\swift\\windows\\x86_64\\swiftCore", .when(platforms: [.windows]))
    ]
    #endif
}

let package = Package(
    name: "Jib",
    platforms: [
        .macOS(.v10_13), .iOS(.v11)
    ],
    products: dynamicLibrary + [
        .library( name: "Jib", targets: ["Jib"])
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Chronometer.git", from: "0.1.0"),
        .package(url: "https://github.com/KittyMac/Hitch.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "CJSCore",
            linkerSettings: linkedLibrary
        ),
        .target(
            name: "CQuickJS",
            linkerSettings: linkedLibrary
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
