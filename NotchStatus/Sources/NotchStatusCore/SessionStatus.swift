import Foundation

public enum SessionState: String, Decodable, Sendable {
    case working, waiting, idle, done
}

/// 一個 Claude Code session 的狀態，對應 hooks/state.sh 寫出的 `<session_id>.json`
public struct SessionStatus: Decodable, Equatable, Sendable {
    public let state: SessionState
    public let project: String
    public let ts: Int
    /// Claude Code 行程的 pid，用來清除已結束 session 的殘留檔；舊格式或找不到時為 nil
    public let pid: Int32?

    public init(state: SessionState, project: String, ts: Int, pid: Int32? = nil) {
        self.state = state
        self.project = project
        self.ts = ts
        self.pid = pid
    }

    /// 格式錯誤或未知的 state 回傳 nil
    public init?(jsonData: Data) {
        guard let decoded = try? JSONDecoder().decode(SessionStatus.self, from: jsonData) else {
            return nil
        }
        self = decoded
    }
}
