/// 瀏海的顯示形態，對應 DynamicNotch 的 hide / compact / expand
public enum NotchMode: Equatable, Sendable {
    case hidden, compact, expanded
}

/// 實際要畫在哪裡
public enum NotchSurface: Equatable, Sendable {
    /// 什麼都不顯示
    case none
    /// 交給 DynamicNotch（只在有瀏海的螢幕上使用）
    case dynamicNotch(NotchMode)
    /// 自己的黑色浮動膠囊：沒有瀏海時，compact（色點）與 expanded（單行）都畫在這裡
    case pill(NotchMode)
}

public enum Presentation {
    /// done 展開後自動收起的秒數
    public static let doneDisplaySeconds: Double = 3

    /// 分級顯示：working / idle 用 compact（不顯眼），waiting / done 用 expanded（顯眼）。
    /// done 展開 `doneDisplaySeconds` 後會被記為 `dismissedDone`，收成 compact（灰點），
    /// 直到下一個狀態出現；之後有新的 done（ts 或 project 不同）會重新展開。
    /// 滑鼠停在瀏海上（`hovering`）時一律展開，顯示所有 session 的清單。
    /// 有瀏海時交給 DynamicNotch。沒有瀏海時 DynamicNotch 會改用 floating 樣式：不支援 compact（會直接隱藏），
    /// 而且是系統 popover 材質，跟黑色膠囊並排不一致——所以沒有瀏海時全部改由膠囊顯示。
    public static func surface(for mode: NotchMode, screenHasNotch: Bool) -> NotchSurface {
        if mode == .hidden { return .none }
        return screenHasNotch ? .dynamicNotch(mode) : .pill(mode)
    }

    public static func mode(
        for status: SessionStatus?,
        dismissedDone: SessionStatus?,
        hovering: Bool = false
    ) -> NotchMode {
        guard let status else { return .hidden }
        if hovering { return .expanded }
        switch status.state {
        case .working, .idle:
            return .compact
        case .waiting:
            return .expanded
        case .done:
            return status == dismissedDone ? .compact : .expanded
        }
    }
}
