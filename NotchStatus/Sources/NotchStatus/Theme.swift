import AppKit
import NotchStatusCore
import SwiftUI

/// 畫面用的顏色與字級。系統原色（`.blue` / `.orange` / `.green`）在純黑底上偏暗偏濁，
/// 這裡改用手調的高亮低飽和色。
enum Theme {
    enum Palette {
        static let working = Color(red: 0.34, green: 0.66, blue: 1.00)
        static let waiting = Color(red: 1.00, green: 0.71, blue: 0.26)
        static let done = Color(red: 0.26, green: 0.84, blue: 0.45)
        static let idle = Color(red: 0.58, green: 0.59, blue: 0.62)
    }

    /// 圓體比系統 UI 字體更貼合瀏海 / 膠囊這種圓角形狀
    static func font(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// AppKit 版本，供 `fitsWidth` 量測文字寬度用
    static func nsFont(_ size: CGFloat, _ weight: NSFont.Weight = .medium) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded),
              let rounded = NSFont(descriptor: descriptor, size: size) else { return base }
        return rounded
    }

    /// compact 與膠囊收起時的專案名
    static let compactLabel = font(12)
    /// 單行狀態與清單
    static let line = font(13)
    static let lineEmphasis = font(13, .semibold)

    /// 色點固定佔用的寬高。實心圓只有 8pt，多出來的空間留給光暈，
    /// 讓光暈不會撐大版面（瀏海 expanded 的黑色區塊是照內容大小算的）。
    static let dotSlot: CGFloat = 14
    static let dotDiameter: CGFloat = 8
}

extension SessionState {
    var color: Color {
        switch self {
        case .working: Theme.Palette.working
        case .waiting: Theme.Palette.waiting
        case .idle: Theme.Palette.idle
        case .done: Theme.Palette.done
        }
    }

    /// compact 色點：done 收起後跟 idle 一樣是「跑完了」，用灰色
    var compactColor: Color {
        self == .done ? Theme.Palette.idle : color
    }

    var symbol: String {
        switch self {
        case .working: "circle.dotted"
        case .waiting: "exclamationmark.triangle.fill"
        case .idle: "moon.fill"
        case .done: "checkmark.circle.fill"
        }
    }
}

/// 狀態色點：實心圓 + 一圈模糊光暈；`breathing`（working）時縮放並淡出淡入。
struct StatusDot: View {
    let color: Color
    let breathing: Bool
    @State private var pulsing = false

    private var active: Bool { breathing && pulsing }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.72)],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: 0,
                    endRadius: Theme.dotDiameter
                )
            )
            .frame(width: Theme.dotDiameter, height: Theme.dotDiameter)
            .background(
                Circle()
                    .fill(color)
                    .frame(width: Theme.dotDiameter, height: Theme.dotDiameter)
                    .blur(radius: 3.5)
                    .opacity(0.75)
            )
            .scaleEffect(active ? 0.82 : 1)
            .opacity(active ? 0.45 : 1)
            .animation(
                breathing ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : nil,
                value: pulsing
            )
            .frame(width: Theme.dotSlot, height: Theme.dotSlot)
            .onAppear { if breathing { pulsing = true } }
    }
}

/// 單行文字，超過 `maxWidth` 時右側漸層淡出（比 `…` 俐落）。
/// 沒超過就完全不套遮罩，否則短名稱的結尾也會被淡掉。
struct FadingText: View {
    let text: String
    let font: Font
    let nsFont: NSFont
    let maxWidth: CGFloat

    private var overflowing: Bool {
        !Text.fitsWidth(text, font: nsFont, maxWidth: maxWidth)
    }

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .clipped()
            .mask(overflowing ? AnyView(fadeMask) : AnyView(Rectangle()))
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.82),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

extension Text {
    /// 文字在該字體下是否塞得進 `maxWidth`
    static func fitsWidth(_ string: String, font: NSFont, maxWidth: CGFloat) -> Bool {
        let width = (string as NSString).size(withAttributes: [.font: font]).width
        return width.rounded(.up) <= maxWidth
    }
}
