import Foundation
import ServiceManagement

/// 開機（登入）自動啟動。
enum LoginItem {
    /// 只有從 Applications 資料夾執行時才註冊：登入項目記錄的是 App 路徑，
    /// 從 repo 裡的開發版（Desktop 底下）註冊的話，之後重建或搬移就會失效，
    /// 而且 macOS 對 Desktop 內的程式有隱私保護，開機自動執行容易被擋。
    static func registerIfInstalled() {
        guard isInApplicationsFolder else {
            NSLog("NotchStatus: not in an Applications folder, skip login item (%@)", Bundle.main.bundlePath)
            return
        }

        let service = SMAppService.mainApp
        guard service.status != .enabled else { return }
        do {
            try service.register()
            NSLog("NotchStatus: registered login item, status=%ld", service.status.rawValue)
        } catch {
            // 常見情況：使用者曾在「系統設定 → 一般 → 登入項目」關掉它（status 為 requiresApproval）
            NSLog("NotchStatus: failed to register login item: %@ (status=%ld)",
                  error.localizedDescription, service.status.rawValue)
        }
    }

    private static var isInApplicationsFolder: Bool {
        let parent = Bundle.main.bundleURL.deletingLastPathComponent().standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return parent == "/Applications" || parent == "\(home)/Applications"
    }
}
