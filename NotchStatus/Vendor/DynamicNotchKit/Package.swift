// swift-tools-version:6.0
// Vendored from https://github.com/MrKai77/DynamicNotchKit — see VENDOR.md
import PackageDescription

let package = Package(
    name: "DynamicNotchKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "DynamicNotchKit", targets: ["DynamicNotchKit"])
    ],
    targets: [
        .target(name: "DynamicNotchKit", path: "Sources")
    ]
)
