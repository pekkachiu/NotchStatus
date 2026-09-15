# Vendored DynamicNotchKit

- 上游：https://github.com/MrKai77/DynamicNotchKit
- 版本：`1.1.0`（commit `cd0b3e52d537db115ad3a9d89601f20e0bee8d27`）
- 授權：MIT（見 `LICENSE`）

## 為什麼要 vendor

本專案只用 Xcode Command Line Tools 建置。CLT 沒有附 SwiftUI 的巨集插件
（`SwiftUIMacros`、`PreviewsMacros`），上游用到的 `@Entry` 與 `#Preview` 無法編譯。

## 與上游的差異

1. 移除 `Documentation.docc`（文件與影片，不影響程式）、`Tests`，以及 `Package.swift` 裡的 `swift-docc-plugin` 依賴。
2. `Utility/EnvironmentValues+Extensions.swift`：`@Entry` 改為手寫 `EnvironmentKey`。
3. `Views/NotchShape.swift`：移除 `#Preview`。
4. `DynamicNotch/DynamicNotch.swift`：`init` 不再呼叫 `observeScreenParameters()`。上游會在螢幕設定改變時把視窗重建到主螢幕，外接螢幕設為主螢幕時會跑到沒有瀏海的那台；改由 `NotchController` 自行處理。
5. `Utility/DynamicNotchPanel.swift`：`collectionBehavior` 加上 `.fullScreenAuxiliary`，讓視窗能出現在全螢幕 App 上。

升級時：拉新版 `Sources/` 覆蓋後，重新套用第 2–5 點。所有修改處都標有 `NotchStatus patch` 註解，可用 `grep -rn 'NotchStatus patch' Sources` 找回來；巨集用 `grep -rn '@Entry\|#Preview' Sources` 檢查。
