import Foundation

/// 畫面文字的語言：跟隨 macOS 的偏好語言，支援英文與繁體中文，其他語言一律英文。
/// 只有幾個狀態名稱要翻譯，所以直接寫在程式裡，不用 .lproj 資源（CLT 手動組 .app 時打包資源很麻煩）。
public enum DisplayLanguage: Equatable, Sendable {
    case english
    case traditionalChinese

    /// 目前系統的偏好語言
    public static var current: DisplayLanguage {
        preferred(from: Locale.preferredLanguages)
    }

    /// 與 macOS 的規則相同：依偏好順序取第一個有支援的語言，都沒有就用英文。
    /// 簡體中文不支援（會繼續往下找，最後退回英文）。
    public static func preferred(from languageTags: [String]) -> DisplayLanguage {
        for tag in languageTags {
            if isTraditionalChinese(tag) { return .traditionalChinese }
            if isEnglish(tag) { return .english }
        }
        return .english
    }

    private static func parts(_ tag: String) -> [String] {
        tag.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
    }

    private static func isEnglish(_ tag: String) -> Bool {
        parts(tag).first == "en"
    }

    /// zh-Hant-*，或沒寫文字系統但地區是台灣、香港、澳門（zh-TW、zh-HK、zh-MO）
    private static func isTraditionalChinese(_ tag: String) -> Bool {
        let p = parts(tag)
        guard p.first == "zh", !p.contains("hans") else { return false }
        return p.contains("hant") || p.contains("tw") || p.contains("hk") || p.contains("mo")
    }
}

extension SessionState {
    /// 狀態名稱（瀏海、膠囊、hover 清單共用）
    public func title(in language: DisplayLanguage) -> String {
        switch (self, language) {
        case (.working, .english): "Working"
        case (.waiting, .english): "Needs you"
        case (.idle, .english): "Idle"
        case (.done, .english): "Done"
        case (.working, .traditionalChinese): "處理中"
        case (.waiting, .traditionalChinese): "等你確認"
        case (.idle, .traditionalChinese): "閒置"
        case (.done, .traditionalChinese): "完成"
        }
    }
}
