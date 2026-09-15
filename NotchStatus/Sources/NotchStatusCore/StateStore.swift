import Foundation

/// 讀取狀態目錄（~/.claude/notch/state）
public enum StateStore {
    public static let defaultDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/notch/state", isDirectory: true)

    /// 讀取目錄下所有 `*.json`。略過 `.` 開頭的檔案（state.sh 的暫存檔）與無法解析的檔案；
    /// 目錄不存在時回傳空陣列。
    ///
    /// 帶 pid 且該行程已結束的檔案會被**刪除**：直接關掉終端機時不會觸發 SessionEnd，
    /// 不清掉的話瀏海會永遠停在那個 session 的狀態。沒有 pid 的檔案一律保留。
    public static func load(
        from directory: URL = defaultDirectory,
        isAlive: (Int32) -> Bool = ProcessLiveness.isAlive
    ) -> [SessionStatus] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> SessionStatus? in
                guard let status = (try? Data(contentsOf: url)).flatMap(SessionStatus.init(jsonData:)) else {
                    return nil
                }
                if let pid = status.pid, !isAlive(pid) {
                    try? FileManager.default.removeItem(at: url)
                    return nil
                }
                return status
            }
    }
}

public enum ProcessLiveness {
    /// 用 kill(pid, 0) 探測行程是否存在（不會真的送訊號）。EPERM 代表存在但屬於別人。
    public static func isAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }
}
