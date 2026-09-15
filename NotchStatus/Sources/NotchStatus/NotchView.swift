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
    /// 膠囊（沒有瀏海時）是否顯示單行展開內容；否則顯示「色點 + 專案名」
    @Published var pillExpanded = false
}

extension SessionState {
    var color: Color {
        switch self {
        case .working: .blue
        case .waiting: .orange
        case .idle: .gray
        case .done: .green
        }
    }

    /// compact 色點：done 收起後跟 idle 一樣是「跑完了」，用灰色
    var compactColor: Color {
        self == .done ? .gray : color
    }

    var symbol: String {
        switch self {
        case .working: "circle.dotted"
        case .waiting: "exclamationmark.triangle.fill"
        case .idle: "moon.fill"
        case .done: "checkmark.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .working: "處理中"
        case .waiting: "等你確認"
        case .idle: "閒置"
        case .done: "完成"
        }
    }
}

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
        }
    }
}

/// 單行狀態「⚠ 等你確認 · 專案名」，瀏海展開與膠囊共用
struct StatusLine: View {
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: status.state.symbol)
                .foregroundStyle(status.state.color)
            Text(status.state.title)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("·")
                .foregroundStyle(.white.opacity(0.4))
            Text(status.project)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .font(.system(size: 13))
    }
}

/// hover 清單：每個 session 一行，狀態指示 + 專案名 + 狀態文字
struct SessionListView: View {
    let sessions: [SessionStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 同一個資料夾可能開多個 session，project 與 ts 都可能相同，用位置當 id
            ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
                HStack(spacing: 8) {
                    StateIndicator(state: session.state)
                        .frame(width: 14)
                    Text(session.project)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 16)
                    Text(session.state.title)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .font(.system(size: 13))
        .frame(minWidth: 200)
    }
}

/// 清單裡的狀態指示：waiting 用警告圖示，其他用與 compact 相同的色點
private struct StateIndicator: View {
    let state: SessionState

    var body: some View {
        if state == .waiting {
            Image(systemName: state.symbol)
                .font(.system(size: 11))
                .foregroundStyle(state.color)
        } else {
            StatusDot(color: state.compactColor, breathing: state == .working)
                .id(state)
        }
    }
}

/// compact 左側：狀態色點，working 時呼吸
struct CompactLeadingView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        if let state = model.status?.state {
            StatusDot(color: state.compactColor, breathing: state == .working)
                // 狀態改變時重建 view，讓呼吸動畫能重新開始或停止
                .id(state)
        }
    }
}

/// compact 右側：專案名稱
struct CompactTrailingView: View {
    @ObservedObject var model: NotchModel

    var body: some View {
        if let project = model.status?.project {
            Text(project)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .frame(maxWidth: 120)
        }
    }
}

struct StatusDot: View {
    let color: Color
    let breathing: Bool
    @State private var dimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(dimmed ? 0.3 : 1)
            .animation(
                breathing ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : nil,
                value: dimmed
            )
            .onAppear { if breathing { dimmed = true } }
    }
}
