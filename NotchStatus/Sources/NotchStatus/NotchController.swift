import Combine
import DynamicNotchKit
import NotchStatusCore
import SwiftUI

/// 把 session 狀態套到瀏海上。
/// DynamicNotch 的 expand/compact/hide 是非同步且需要動畫時間，所以一次只套一個，
/// 套完再檢查目標有沒有又變，直到跟最新狀態一致。
@MainActor
final class NotchController {
    private let model = NotchModel()
    private let notch: DynamicNotch<ExpandedView, CompactLeadingView, CompactTrailingView>
    /// 沒有瀏海時取代 compact
    private let pill: PillWindow

    private var target: SessionStatus?
    private var dismissedDone: SessionStatus?
    /// 滑鼠是否停在瀏海上（DynamicNotch 在瀏海顯示中才會回報）
    private var hovering = false
    private var appliedStatus: SessionStatus?
    private var appliedMode: NotchMode = .hidden
    private var appliedHovering = false
    private var isApplying = false
    private var doneDismissTask: Task<Void, Never>?
    /// 螢幕設定改變（插拔、改解析度、合上螢幕）後，要把目前的瀏海收起再重新顯示到正確的螢幕
    private var needsRelayout = false
    private var screenObserver: NSObjectProtocol?
    private var hoverSubscription: AnyCancellable?

    init() {
        let model = model
        notch = DynamicNotch(hoverBehavior: .keepVisible) {
            ExpandedView(model: model)
        } compactLeading: {
            CompactLeadingView(model: model)
        } compactTrailing: {
            CompactTrailingView(model: model)
        }
        pill = PillWindow(model: model)
        // compact ↔ expanded 直接變形，不先收起再展開：hover 切換時才不會閃
        notch.transitionConfiguration.skipIntermediateHides = true

        hoverSubscription = notch.$isHovering
            .removeDuplicates()
            .sink { [weak self] isHovering in
                MainActor.assumeIsolated { self?.hoverDidChange(isHovering) }
            }
        // vendor 版 DynamicNotchKit 已不自行處理螢幕變化（見 VENDOR.md），由這裡負責
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensDidChange() }
        }
    }

    private func screensDidChange() {
        needsRelayout = true
        applyLatest()
    }

    private func hoverDidChange(_ isHovering: Bool) {
        hovering = isHovering
        applyLatest()
    }

    /// 傳入目前所有 session；聚合結果決定平常的顯示，完整清單在 hover 時顯示
    func update(_ sessions: [SessionStatus]) {
        let sorted = Aggregator.sortedForList(sessions)
        // 清單內容隨時更新，hover 中也能即時看到變化
        if sorted != model.sessions { model.sessions = sorted }

        let status = sorted.first
        guard status != target else { return }
        target = status
        applyLatest()
    }

    private func applyLatest() {
        guard !isApplying else { return } // 正在套用中，迴圈結束前會再檢查一次 target
        isApplying = true
        Task {
            await applyUntilSettled()
            isApplying = false
        }
    }

    private func applyUntilSettled() async {
        while true {
            if needsRelayout {
                // 連續多次螢幕變化只會處理一次；hide 會銷毀視窗，下面的 transition 再依目前的螢幕重建
                needsRelayout = false
                if appliedMode != .hidden {
                    NSLog("NotchStatus: screens changed, relayout")
                    pill.hide(animated: false)
                    await notch.hide()
                    appliedMode = .hidden
                }
            }

            let status = target
            let isHovering = hovering
            let mode = Presentation.mode(for: status, dismissedDone: dismissedDone, hovering: isHovering)
            if status == appliedStatus, mode == appliedMode, isHovering == appliedHovering, !needsRelayout {
                return
            }

            // 收起時保留舊內容，讓收起動畫顯示的還是原本的東西
            if let status { model.status = status }
            let showList = isHovering && status != nil
            // 收起（expanded → compact/hidden）時，清單要留到動畫結束才換掉；
            // 若先換回單行內容，收起的那 0.4 秒會露出聚合狀態（例如已收成灰點的「✓ 完成」）
            let collapsing = appliedMode == .expanded && mode != .expanded
            if !collapsing { model.showingList = showList }
            NSLog("NotchStatus: %@ %@ -> %@%@", status?.state.rawValue ?? "none", status?.project ?? "-",
                  "\(mode)", isHovering ? " (list)" : "")
            if mode != appliedMode { await transition(to: mode) }
            if collapsing { model.showingList = showList }
            appliedStatus = status
            appliedMode = mode
            appliedHovering = isHovering

            // done 的 3 秒計時看的是「沒有 hover 時」的顯示，hover 中照樣倒數
            if let status, status.state == .done, status != dismissedDone, status != scheduledDone {
                scheduleDoneDismissal(of: status)
            }
        }
    }

    private func transition(to mode: NotchMode) async {
        let screen = Self.notchScreen
        switch Presentation.surface(for: mode, screenHasNotch: Self.hasNotch(screen)) {
        case .none:
            pill.hide()
            await notch.hide()
        case .pill(let pillMode):
            await notch.hide()
            model.pillExpanded = pillMode == .expanded
            pill.show(on: screen)
        case .dynamicNotch(.compact):
            pill.hide()
            await notch.compact(on: screen)
        case .dynamicNotch(.expanded):
            pill.hide()
            await notch.expand(on: screen)
        case .dynamicNotch(.hidden):
            pill.hide()
            await notch.hide()
        }
    }

    /// 有瀏海的螢幕；都沒有才退回主螢幕（那時 DynamicNotch 會用 floating 樣式，compact 改由膠囊顯示）。
    /// DynamicNotch 預設用 `NSScreen.screens[0]`（主螢幕），外接螢幕設為主螢幕時會跑到沒有瀏海的那台。
    private static var notchScreen: NSScreen {
        NSScreen.screens.first(where: hasNotch) ?? NSScreen.screens[0]
    }

    /// 判斷條件與 DynamicNotchKit 內部的 `hasNotch` 相同（該屬性不是 public）。
    /// `NOTCH_FORCE_NO_NOTCH`：測試用，假裝所有螢幕都沒有瀏海（不用合上 MacBook 就能測膠囊）。
    private static func hasNotch(_ screen: NSScreen) -> Bool {
        // 空字串視同沒設定，避免腳本傳 NOTCH_FORCE_NO_NOTCH="" 時意外變成沒有瀏海
        if let force = ProcessInfo.processInfo.environment["NOTCH_FORCE_NO_NOTCH"], !force.isEmpty { return false }
        return screen.auxiliaryTopLeftArea != nil && screen.auxiliaryTopRightArea != nil
    }

    /// 目前正在倒數的 done，避免 hover 切換時重複重設計時
    private var scheduledDone: SessionStatus?

    private func scheduleDoneDismissal(of status: SessionStatus) {
        scheduledDone = status
        doneDismissTask?.cancel()
        doneDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Presentation.doneDisplaySeconds))
            guard !Task.isCancelled, let self else { return }
            dismissedDone = status
            applyLatest()
        }
    }
}
