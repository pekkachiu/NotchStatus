// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotchStatus",
    platforms: [.macOS(.v13)],
    dependencies: [
        // vendor 版，修改內容見 Vendor/DynamicNotchKit/VENDOR.md
        .package(path: "Vendor/DynamicNotchKit")
    ],
    targets: [
        // 純邏輯（狀態解析、聚合、顯示形態），不依賴 UI，方便測試
        .target(name: "NotchStatusCore"),
        .executableTarget(
            name: "NotchStatus",
            dependencies: ["NotchStatusCore", "DynamicNotchKit"]
        ),
        .testTarget(
            name: "NotchStatusCoreTests",
            dependencies: ["NotchStatusCore"]
        )
    ]
)
