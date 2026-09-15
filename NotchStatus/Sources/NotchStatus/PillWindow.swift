import AppKit
import NotchStatusCore
import SwiftUI

/// 沒有瀏海的螢幕（例如合上 MacBook 只用外接螢幕）上，取代 DynamicNotch 的黑色浮動膠囊。
/// DynamicNotch 在那裡會用 floating 樣式：不支援 compact（working / 跑完了會完全看不到），
/// 而且是系統 popover 材質，跟黑色不一致——所以全部狀態都畫在這個膠囊上。
///
/// 滑鼠停在上面時，膠囊本身長成所有 session 的清單，hover 全在同一個視窗內處理，不會反覆展開收起。
@MainActor
final class PillWindow {
    private let model: NotchModel
    private var panel: NSPanel?

    /// 視窗比膠囊大、背景透明，膠囊展開成清單時不用改視窗大小（透明區域的點擊會穿透到下層）
    private static let windowSize = NSSize(width: 360, height: 240)
    /// 膠囊與選單列之間的距離
    private static let topGap: CGFloat = 6
    private static let fadeDuration: TimeInterval = 0.2

    init(model: NotchModel) {
        self.model = model
    }

    func show(on screen: NSScreen) {
        if let panel, panel.isVisible, panel.screen == screen { return }
        hide(animated: false)

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        // 與 DynamicNotchPanel 相同：不搶焦點、出現在所有桌面與全螢幕 App 上
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        // 每次顯示都重建 view，hover 狀態不會殘留
        panel.contentView = NSHostingView(rootView: PillView(model: model))

        // visibleFrame 已扣掉選單列；膠囊貼著選單列下方、水平置中
        let size = Self.windowSize
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.visibleFrame.maxY - Self.topGap - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 1
        }
        self.panel = panel
    }

    func hide(animated: Bool = true) {
        guard let panel else { return }
        self.panel = nil
        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = 0
        } completionHandler: {
            // AppKit 動畫的 completion 在主執行緒執行
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }
}

/// 黑色膠囊：compact 顯示「色點 + 專案名」，expanded 顯示單行狀態（waiting / done），hover 時長成清單
private struct PillView: View {
    @ObservedObject var model: NotchModel
    @State private var hovering = false

    private var showingList: Bool { hovering && !model.sessions.isEmpty }

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, showingList ? 12 : 7)
            .background(
                RoundedRectangle(cornerRadius: showingList ? 16 : 14, style: .continuous)
                    .fill(.black)
            )
            .onHover { hovering = $0 }
            .animation(.snappy(duration: 0.25), value: showingList)
            .animation(.snappy(duration: 0.25), value: model.pillExpanded)
            .animation(.snappy(duration: 0.25), value: model.status)
            // 貼齊視窗頂端置中，往下長
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var content: some View {
        if showingList {
            SessionListView(sessions: model.sessions)
        } else if let status = model.status, model.pillExpanded {
            StatusLine(status: status)
        } else if let status = model.status {
            HStack(spacing: 8) {
                StatusDot(color: status.state.compactColor, breathing: status.state == .working)
                    .id(status.state)
                Text(status.project)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: 160)
            }
        }
    }
}
