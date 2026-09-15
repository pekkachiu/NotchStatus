/// 把多個 session 聚合成瀏海要顯示的單一狀態
public enum Aggregator {
    /// 優先序 waiting > working > idle = done；同一級取最近觸發（ts 最大）的 session。
    /// idle 與 done 都代表「跑完了、等下一個指令」，所以同級，讓剛完成的 session 能蓋過較早閒置的。
    /// 沒有任何 session 時回傳 nil。
    public static func aggregate(_ sessions: [SessionStatus]) -> SessionStatus? {
        sessions.max(by: isLessUrgent)
    }

    /// hover 清單的順序：與 `aggregate` 同一套規則由急到緩排列，第一個就是聚合結果
    public static func sortedForList(_ sessions: [SessionStatus]) -> [SessionStatus] {
        sessions.sorted { isLessUrgent($1, than: $0) }
    }

    private static func isLessUrgent(_ lhs: SessionStatus, than rhs: SessionStatus) -> Bool {
        (priority(lhs.state), lhs.ts) < (priority(rhs.state), rhs.ts)
    }

    private static func priority(_ state: SessionState) -> Int {
        switch state {
        case .waiting: 3
        case .working: 2
        case .idle, .done: 1
        }
    }
}
