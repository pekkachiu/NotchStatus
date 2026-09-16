import NotchStatusCore
import SwiftUI

/// 瀏海目前顯示的內容。DynamicNotch 在初始化時就固定了 view，所以內容要透過這個 model 更新。
@MainActor
final class NotchModel: ObservableObject {
    /// 聚合後的狀態（compact 與單行 expanded 用）
    @Published var status: SessionStatus?
    /// 所有 session，已依急迫程度排序（hover 清單用）
    @Published var sessions: [SessionStatus] = []
    /// 滑鼠停在瀏海上時，expanded 改顯示清單
    @Published var showingList = false
    /// 膠囊（沒有瀏海時）是否顯示單行展開內容；否則顯示「吉祥物 + 專案名」
    @Published var pillExpanded = false
}

extension SessionState {
    /// 狀態名稱，跟隨系統語言（英文或繁體中文，見 `DisplayLanguage`）
    var title: String {
        title(in: appLanguage)
    }
}

/// App 啟動時決定一次；改了系統語言要重開 App 才會生效
private let appLanguage = DisplayLanguage.current

/// expanded：平常用於 waiting 與 done（單行）；hover 時改顯示所有 session 的清單。
/// DynamicNotch 會在上方預留瀏海高度、下方與左右各留 15pt，所以內容本身不加 padding，
/// 讓展開的黑色區塊維持扁長方形而不是方塊。
struct ExpandedView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        if model.showingList {
            SessionListView(sessions: model.sessions)
        } else if let status = model.status {
            StatusLine(status: status)
                .animation(.smooth(duration: 0.25), value: status)
        }
    }
}

/// 單行狀態「吉祥物 · 等你確認 · 專案名」，瀏海展開與膠囊共用
struct StatusLine: View {
    let status: SessionStatus

    var body: some View {
        // 底部對齊：吉祥物的框比文字高（上方留給跳躍），讓牠跟文字站在同一條地平線上
        HStack(alignment: .bottom, spacing: 7) {
            // 狀態改變時重建，動作才會換成新狀態的
            MascotView(
                state: status.state,
                // expanded 的 done 是剛跑完（淡桃色），不是收起後的暗色
                color: status.state.color,
                headroom: Theme.mascotHeadroom
            )
            .id(status.state)
            Text(status.state.title)
                .font(Theme.lineEmphasis)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
            Text("·")
                .foregroundStyle(.white.opacity(0.35))
            Text(status.project)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .font(Theme.line)
    }
}

/// hover 清單：每個 session 一行，狀態指示 + 專案名 + 狀態文字
struct SessionListView: View {
    let sessions: [SessionStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 同一個資料夾可能開多個 session，project 與 ts 都可能相同，用位置當 id
            ForEach(Array(sessions.enumerated()), id: \.offset) { index, session in
                SessionRow(session: session, index: index)
            }
        }
        .font(Theme.line)
        .frame(minWidth: 200)
    }
}

/// 清單的一行。展開時依序淡入（每行差 30ms），整塊同時出現比較死板。
private struct SessionRow: View {
    let session: SessionStatus
    let index: Int
    @State private var shown = false

    var body: some View {
        HStack(spacing: 8) {
            StateIndicator(state: session.state)
                .frame(width: Theme.dotSlot)
            Text(session.project)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 16)
            Text(session.state.title)
                .foregroundStyle(.white.opacity(0.55))
                // 狀態文字靠右對齊成一欄，長度不一才不會參差
                .frame(minWidth: 58, alignment: .trailing)
        }
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : -3)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2).delay(Double(index) * 0.03)) { shown = true }
        }
    }
}

/// 清單裡的狀態指示：waiting 用警告圖示，其他用色點。
/// 這裡不用吉祥物——四隻一起動太吵，行高也會被撐大。
private struct StateIndicator: View {
    let state: SessionState

    var body: some View {
        if state == .waiting {
            Image(systemName: state.symbol)
                .font(.system(size: 11))
                .foregroundStyle(state.color)
                .symbolEffect(.pulse, options: .repeating)
        } else {
            StatusDot(color: state.compactColor, breathing: state == .working)
                .id(state)
        }
    }
}

/// compact 左側：吉祥物，依狀態播不同動作
struct CompactLeadingView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        if let state = model.status?.state {
            // 狀態改變時重建 view，讓動作換成新狀態的
            MascotView(state: state.compactState)
                .id(state)
        }
    }
}

/// compact 右側：專案名稱
struct CompactTrailingView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        if let project = model.status?.project {
            FadingText(
                text: project,
                font: Theme.compactLabel,
                nsFont: Theme.nsFont(12),
                maxWidth: 120
            )
            .foregroundStyle(.white.opacity(0.85))
        }
    }
}
