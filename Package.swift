// swift-tools-version: 5.6

import PackageDescription
import Foundation

// By default, Jib will use JavascriptCore on all platforms. If you would
// like to try QuickJS instead, you can set the appropriate environment variable
// setenv("JIB", "JSC", 1)
// setenv("JIB", "QJS", 1)
//
// NOTE: for Windows, you need to manually copy the DLLs from the DLL folder to
// some place in your PATH. For development, you can copy them into the .build
// folder.
//
// NOTE: to updated to newer versions of JSC on Windows, follow these directions:
// https://docs.webkit.org/Ports/WindowsPort.html#downloading-build-artifacts-from-buildbot
// Download the archive from the buildbot, copy the DLL from bin64
// Download the WebKitRequirements, copy the DLL from the bin64
// You might need to generate a new .lib from JavaScriptCore.dll, in which case
// use this tool: https://github.com/KHeresy/GenLibFromDll

var engine: String = ProcessInfo.processInfo.environment["JIB"] ?? "JSC"

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
        linkedLibrary = [
            .linkedLibrary("javascriptcoregtk-4.0"),
        ]
    } else if FileManager.default.fileExists(atPath: "/usr/include/webkitgtk-4.1") {
        linkedLibrary = [
            .linkedLibrary("javascriptcoregtk-4.1"),
        ]
    }
    #endif
    #if os(Windows)
    let sdkRoot: String = ProcessInfo.processInfo.environment["SDKROOT"]!
    linkedLibrary = [
        .linkedLibrary("JibDLL/JavaScriptCore", .when(platforms: [.windows])),
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
        .linkedLibrary("\(sdkRoot)usr\\lib\\swift\\windows\\x86_64\\swiftCore")
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
