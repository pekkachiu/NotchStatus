import Testing
@testable import NotchStatusCore

@Suite struct PresentationTests {
    private let done = SessionStatus(state: .done, project: "a", ts: 100)

    @Test func nothingIsHidden() {
        #expect(Presentation.mode(for: nil, dismissedDone: nil) == .hidden)
    }

    @Test(arguments: [SessionState.working, .idle])
    func lowUrgencyIsCompact(state: SessionState) {
        let status = SessionStatus(state: state, project: "a", ts: 1)
        #expect(Presentation.mode(for: status, dismissedDone: nil) == .compact)
    }

    @Test func waitingIsExpanded() {
        let status = SessionStatus(state: .waiting, project: "a", ts: 1)
        #expect(Presentation.mode(for: status, dismissedDone: nil) == .expanded)
    }

    @Test func freshDoneIsExpanded() {
        #expect(Presentation.mode(for: done, dismissedDone: nil) == .expanded)
    }

    @Test func dismissedDoneCollapsesToCompact() {
        // 完成展開 3 秒後收成灰點，不隱藏
        #expect(Presentation.mode(for: done, dismissedDone: done) == .compact)
    }

    @Test func newerDoneShowsAgainAfterDismissal() {
        let newer = SessionStatus(state: .done, project: "b", ts: 200)
        #expect(Presentation.mode(for: newer, dismissedDone: done) == .expanded)
    }

    @Test(arguments: [SessionState.working, .waiting, .idle, .done])
    func hoveringExpandsAnyVisibleState(state: SessionState) {
        let status = SessionStatus(state: state, project: "a", ts: 1)
        #expect(Presentation.mode(for: status, dismissedDone: nil, hovering: true) == .expanded)
        #expect(Presentation.mode(for: status, dismissedDone: status, hovering: true) == .expanded)
    }

    @Test func hoveringWithNothingStaysHidden() {
        #expect(Presentation.mode(for: nil, dismissedDone: nil, hovering: true) == .hidden)
    }

    @Test func surfaceOnNotchedScreenUsesDynamicNotch() {
        #expect(Presentation.surface(for: .hidden, screenHasNotch: true) == .none)
        #expect(Presentation.surface(for: .compact, screenHasNotch: true) == .dynamicNotch(.compact))
        #expect(Presentation.surface(for: .expanded, screenHasNotch: true) == .dynamicNotch(.expanded))
    }

    @Test func surfaceWithoutNotchUsesPillForEverything() {
        // 沒有瀏海時全部畫在自己的黑色膠囊上，外觀才一致（DynamicNotch 的 floating 樣式不支援 compact、材質也不同）
        #expect(Presentation.surface(for: .hidden, screenHasNotch: false) == .none)
        #expect(Presentation.surface(for: .compact, screenHasNotch: false) == .pill(.compact))
        #expect(Presentation.surface(for: .expanded, screenHasNotch: false) == .pill(.expanded))
    }

    @Test func doneDisplaysForThreeSeconds() {
        #expect(Presentation.doneDisplaySeconds == 3)
    }
}
