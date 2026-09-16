import NotchStatusCore
import SwiftUI

/// 吉祥物的 pixel art。用 `Canvas` 畫格子而不是貼圖：任何尺寸都銳利、不用打包圖檔，
/// 而且腳與眼睛可以各自動起來。
///
/// 13 × 9 格。高度取 `Theme.mascotHeight`（18pt）時每格剛好 2pt，在 Retina 上是整數 4px，邊緣不會糊。
///
/// ```
///   . . ####### . .
///   . . ####### . .
///   . . #O###O# . .   O = 眼睛（挖空）
///   ####O###O####     兩側是短手
///   #############
///   . . ####### . .
///   . . ####### . .
///   . . # # # # . .   四隻腳
///   . . # # # # . .
/// ```
struct MascotSprite: View {
    let color: Color
    /// 每隻腳縮短的格數（由左到右）。腳是從下緣往上縮，不會疊到身體——
    /// evenOdd 填色下，疊到身體的部分會變成洞。
    var legLift: [CGFloat] = [0, 0, 0, 0]
    /// 眼睛張開程度：1 = 全開，接近 0 = 閉上
    var eyeOpen: CGFloat = 1
    var height: CGFloat = Theme.mascotHeight

    static let cols: CGFloat = 13
    static let rows: CGFloat = 9
    static var aspect: CGFloat { cols / rows }

    var body: some View {
        Canvas { context, size in
            let cell = size.height / Self.rows
            func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: x * cell, y: y * cell, width: w * cell, height: h * cell)
            }

            var path = Path()
            path.addRect(box(2, 0, 9, 7)) // 身體
            path.addRect(box(0, 3, 2, 2)) // 左手
            path.addRect(box(11, 3, 2, 2)) // 右手
            for (index, x) in [CGFloat(2), 4, 8, 10].enumerated() {
                let lift = min(legLift[index], 2)
                path.addRect(box(x, 7, 1, 2 - lift))
            }
            // 眼睛用 evenOdd 挖成真正的洞，底下是什麼顏色都對
            let eyeHeight = max(0.3, 2 * eyeOpen)
            let eyeY = 2 + (2 - eyeHeight) / 2
            path.addRect(box(4, eyeY, 1, eyeHeight))
            path.addRect(box(8, eyeY, 1, eyeHeight))

            context.fill(path, with: .color(color), style: FillStyle(eoFill: true))
        }
        .frame(width: height * Self.aspect, height: height)
    }
}

/// 依狀態播不同動作的吉祥物。
/// 顏色一律是吉祥物的陶土橘，各狀態只差在明暗與飽和度（見 `Theme.Palette`）。
struct MascotView: View {
    let state: SessionState
    /// 由呼叫端決定：compact 的 done 已經是「跑完收起」，要用暗色（`compactColor`）
    var color: Color
    var height: CGFloat = Theme.mascotHeight
    /// 上方預留的空間。expanded 的內容緊貼瀏海下緣，不留的話跳起來會進到實體瀏海裡被遮住。
    var headroom: CGFloat = 0

    init(state: SessionState, color: Color? = nil, height: CGFloat = Theme.mascotHeight, headroom: CGFloat = 0) {
        self.state = state
        self.color = color ?? state.compactColor
        self.height = height
        self.headroom = headroom
    }

    /// idle 時右邊要留位置給飄出來的 Z
    private var zSlot: CGFloat { state == .idle ? height * 0.7 : 0 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            animated
            if state == .idle {
                // 瀏海 compact 的內容區只有 16pt 高（安全區上 4 下 8），Z 不能往上長，
                // 只能在吉祥物現有的高度內、從頭部旁邊往右上飄
                SleepingZs(color: color, height: height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        // 跳躍發生在這個框裡面，不會溢出去；整隻因此往下坐，文字行也跟著對齊底部
        .frame(width: height * MascotSprite.aspect + zSlot, height: height + headroom, alignment: .bottomLeading)
    }

    @ViewBuilder
    private var animated: some View {
        switch state {
        case .working: walking
        case .waiting: alerting
        case .idle: sleeping
        case .done: celebrating
        }
    }

    /// 處理中：兩組腳交替縮放，身體跟著上下晃，像在走路。
    /// pixel art 本來就是一格一格換，腳直接跳不補間才對味。
    private var walking: some View {
        PhaseAnimator([0, 1]) { phase in
            MascotSprite(
                color: color,
                legLift: phase == 0 ? [0.7, 0, 0, 0.7] : [0, 0.7, 0.7, 0],
                height: height
            )
            .offset(y: phase == 0 ? -0.5 : 0.5)
        } animation: { _ in
            .easeInOut(duration: 0.34)
        }
    }

    /// 等你確認：停一下、跳一下，重複。常駐時要抓得到眼睛又不能一直在動。
    private var alerting: some View {
        PhaseAnimator([0, 1, 2]) { phase in
            MascotSprite(
                color: color,
                legLift: phase == 1 ? [1, 1, 1, 1] : [0, 0, 0, 0],
                height: height
            )
            .offset(y: phase == 1 ? -height / 6 : 0)
        } animation: { phase in
            switch phase {
            case 1: .easeOut(duration: 0.16)
            case 2: .easeIn(duration: 0.2)
            default: .linear(duration: 1.1)
            }
        }
    }

    /// 閒置 / 跑完收起後：閉著眼睛，緩慢地呼吸（旁邊還會飄 Z，見 `SleepingZs`）
    private var sleeping: some View {
        PhaseAnimator([0, 1]) { phase in
            MascotSprite(color: color, eyeOpen: 0.1, height: height)
                .scaleEffect(y: phase == 0 ? 1 : 0.94, anchor: .bottom)
        } animation: { _ in
            .easeInOut(duration: 2.4)
        }
    }

    /// 完成：出現時開心地跳一下就停住（只播一次）
    private var celebrating: some View {
        KeyframeAnimator(initialValue: CGFloat.zero) { offset in
            MascotSprite(
                color: color,
                legLift: offset < -0.5 ? [1, 1, 1, 1] : [0, 0, 0, 0],
                height: height
            )
            .offset(y: offset)
        } keyframes: { _ in
            SpringKeyframe(-height / 4, duration: 0.2, spring: .snappy)
            SpringKeyframe(0, duration: 0.42, spring: .bouncy)
        }
    }
}

/// 睡覺時飄出來的 Z。兩個大小不同、錯開半個週期，沿同一條軌跡往右上飄並淡出，
/// 一個週期 2.4 秒，跟呼吸同拍。
private struct SleepingZs: View {
    let color: Color
    /// 吉祥物高度；Z 的大小與飄行距離都照它算
    let height: CGFloat

    /// 軌跡的四個落點：由下往上，中途最亮、到頂淡掉。
    /// 第 3 步回到第 0 步時會整個滑回底下，但兩端的不透明度都是 0，看不到。
    private static let riseRatios: [CGFloat] = [0.45, 0.30, 0.15, 0]
    private static let drifts: [CGFloat] = [-3, -2, -1, 0]
    private static let opacities: [Double] = [0, 1, 0.7, 0]

    var body: some View {
        PhaseAnimator([0, 1, 2, 3]) { phase in
            ZStack(alignment: .topTrailing) {
                floatingZ(cell: height / 12, step: phase, baseX: -height * 0.12)
                floatingZ(cell: height / 18, step: (phase + 2) % 4, baseX: 0)
            }
        } animation: { _ in
            .linear(duration: 0.6)
        }
    }

    private func floatingZ(cell: CGFloat, step: Int, baseX: CGFloat) -> some View {
        ZGlyph(color: color, cell: cell)
            .opacity(Self.opacities[step])
            .offset(x: baseX + Self.drifts[step], y: height * Self.riseRatios[step])
    }
}

/// 4 × 4 格的 pixel Z。3 × 3 的話中間只剩一格，看起來像「I」而不是「Z」。
///
/// ```
///   ####
///   ..#.
///   .#..
///   ####
/// ```
private struct ZGlyph: View {
    let color: Color
    let cell: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.addRect(CGRect(x: 0, y: 0, width: cell * 4, height: cell)) // 上橫
            path.addRect(CGRect(x: cell * 2, y: cell, width: cell, height: cell)) // 斜線
            path.addRect(CGRect(x: cell, y: cell * 2, width: cell, height: cell))
            path.addRect(CGRect(x: 0, y: cell * 3, width: cell * 4, height: cell)) // 下橫
            context.fill(path, with: .color(color))
        }
        .frame(width: cell * 4, height: cell * 4)
    }
}
