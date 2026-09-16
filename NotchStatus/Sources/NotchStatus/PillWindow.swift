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

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: showingList ? 16 : 14, style: .continuous)
    }

    /// 純黑方塊看起來像貼上去的色塊；加上細描邊、頂部高光與陰影，才像實體元件
    private var background: some View {
        shape
            .fill(.black)
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(0.07), .white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            )
            .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 1))
            // 視窗比膠囊大且背景透明，陰影有空間可畫（NSPanel 的 hasShadow 是關的）
            .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
    }

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, showingList ? 12 : 7)
            .background(background)
            // 內容切換的動畫中，新內容會比黑底先長大；裁在同一個形狀內，文字才不會露到膠囊外面
            .clipShape(shape)
            .onHover { hovering = $0 }
            .animation(Self.transition, value: showingList)
            .animation(Self.transition, value: model.pillExpanded)
            .animation(Self.transition, value: model.status)
            // 貼齊視窗頂端置中，往下長
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// 帶一點回彈的 spring，比等速的 snappy 有生氣
    private static let transition: Animation = .spring(response: 0.34, dampingFraction: 0.72)

    @ViewBuilder
    private var content: some View {
        if showingList {
            // fixedSize：清單裡有 Spacer，不固定的話會被撐到整個視窗寬（DynamicNotch 內部也是這樣處理）
            SessionListView(sessions: model.sessions)
                .fixedSize()
        } else if let status = model.status, model.pillExpanded {
            StatusLine(status: status)
        } else if let status = model.status {
            HStack(spacing: 8) {
                MascotView(state: status.state)
                    .id(status.state)
                FadingText(
                    text: status.project,
                    font: Theme.compactLabel,
                    nsFont: Theme.nsFont(12),
                    maxWidth: 160
                )
                .foregroundStyle(.white.opacity(0.9))
            }
            // 視窗比膠囊寬，不固定的話 maxWidth 會把短名稱也撐到 160pt，膠囊中間出現大片空白
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}
