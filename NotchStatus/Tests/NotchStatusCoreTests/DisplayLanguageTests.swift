import Testing
@testable import NotchStatusCore

@Suite struct DisplayLanguageTests {
    @Test(arguments: ["zh-Hant-TW", "zh-Hant", "zh-TW", "zh-HK", "zh-MO", "zh-Hant-HK"])
    func traditionalChineseVariants(tag: String) {
        #expect(DisplayLanguage.preferred(from: [tag]) == .traditionalChinese)
    }

    @Test(arguments: ["en-US", "en", "en-GB"])
    func englishVariants(tag: String) {
        #expect(DisplayLanguage.preferred(from: [tag]) == .english)
    }

    @Test func unsupportedLanguagesFallBackToEnglish() {
        #expect(DisplayLanguage.preferred(from: ["ja-JP"]) == .english)
        #expect(DisplayLanguage.preferred(from: ["fr-FR", "de-DE"]) == .english)
        #expect(DisplayLanguage.preferred(from: []) == .english)
    }

    @Test func simplifiedChineseIsNotSupported() {
        // 簡體中文不支援，退回英文
        #expect(DisplayLanguage.preferred(from: ["zh-Hans-CN"]) == .english)
        #expect(DisplayLanguage.preferred(from: ["zh-CN"]) == .english)
    }

    @Test func firstSupportedLanguageInListWins() {
        // 跟 macOS 的規則一樣：依偏好順序，取第一個有支援的語言
        #expect(DisplayLanguage.preferred(from: ["ja-JP", "zh-Hant-TW", "en-US"]) == .traditionalChinese)
        #expect(DisplayLanguage.preferred(from: ["zh-Hans-CN", "en-US", "zh-Hant-TW"]) == .english)
        #expect(DisplayLanguage.preferred(from: ["en-US", "zh-Hant-TW"]) == .english)
    }

    @Test func titlesInTraditionalChinese() {
        let zh = DisplayLanguage.traditionalChinese
        #expect(SessionState.working.title(in: zh) == "處理中")
        #expect(SessionState.waiting.title(in: zh) == "等你確認")
        #expect(SessionState.idle.title(in: zh) == "閒置")
        #expect(SessionState.done.title(in: zh) == "完成")
    }

    @Test func titlesInEnglish() {
        let en = DisplayLanguage.english
        #expect(SessionState.working.title(in: en) == "Working")
        #expect(SessionState.waiting.title(in: en) == "Needs you")
        #expect(SessionState.idle.title(in: en) == "Idle")
        #expect(SessionState.done.title(in: en) == "Done")
    }
}
