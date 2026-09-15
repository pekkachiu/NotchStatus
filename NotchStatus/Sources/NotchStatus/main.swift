import AppKit
import NotchStatusCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var watcher: StateWatcher?
    private var livenessTimer: Timer?

    /// 直接關掉終端機不會產生任何檔案變動，所以定期重讀一次，讓 StateStore 清掉已結束 session 的檔案
    private static let livenessCheckInterval: TimeInterval = 10

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.registerIfInstalled()

        // NOTCH_STATE_DIR：測試用，改看其他目錄，避免被正在跑的 Claude session 干擾
        let directory = ProcessInfo.processInfo.environment["NOTCH_STATE_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) } ?? StateStore.defaultDirectory
        // FSEvents 需要目錄存在才能監看
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let controller = NotchController()
        let refresh: @MainActor () -> Void = {
            controller.update(StateStore.load(from: directory))
        }
        let watcher = StateWatcher(directory: directory, onChange: refresh)
        watcher.start()

        self.controller = controller
        self.watcher = watcher
        livenessTimer = Timer.scheduledTimer(withTimeInterval: Self.livenessCheckInterval, repeats: true) { _ in
            MainActor.assumeIsolated { refresh() }
        }
        refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Info.plist 已設 LSUIElement，這裡再保險一次：不出現在 Dock
app.setActivationPolicy(.accessory)
app.run()
