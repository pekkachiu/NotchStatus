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
/// 顏色仍然跟著狀態走（藍 / 琥珀 / 灰 / 綠）——一眼分辨狀態是這個 App 的本體，
/// 全部都用吉祥物原本的陶土色會失去這個作用。
struct MascotView: View {
    let state: SessionState
    var height: CGFloat = Theme.mascotHeight

    private var color: Color { state.compactColor }

    var body: some View {
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

    /// 閒置 / 跑完收起後：閉著眼睛，緩慢地呼吸
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
