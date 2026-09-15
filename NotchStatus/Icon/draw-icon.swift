// 產生 App 圖示的 1024×1024 PNG（藍色漸層圓角方形 + 黑色膠囊 + 藍點 + 專案名橫條）。
// 用法：在 NotchStatus/ 下執行 ./Icon/make-icon.sh（會呼叫本檔並轉成 AppIcon.icns）
import AppKit

let outPath = CommandLine.arguments[1]
// macOS 圖示網格：1024 畫布、824 圓角方形，四周留邊給陰影
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let corner: CGFloat = 185

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: a)
}

func withShadow(blur: CGFloat, offsetY: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(alpha)
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let squircle = NSBezierPath(roundedRect: body, xRadius: corner, yRadius: corner)
withShadow(blur: 30, offsetY: -14, alpha: 0.35) {
    NSColor.black.setFill()
    squircle.fill()
}

NSGraphicsContext.saveGraphicsState()
squircle.addClip()
NSGradient(starting: hex(0x4F8BFF), ending: hex(0x1E40AF))!.draw(in: body, angle: -90)

// 黑色膠囊
let pill = NSRect(x: body.midX - 310, y: body.midY - 95, width: 620, height: 190)
withShadow(blur: 30, offsetY: -10, alpha: 0.35) {
    NSColor.black.setFill()
    NSBezierPath(roundedRect: pill, xRadius: 95, yRadius: 95).fill()
}

// 帶光暈的藍點
let blue = hex(0x3B82F6)
let dot = NSPoint(x: pill.minX + 115, y: pill.midY)
let dotRadius: CGFloat = 38, glowRadius = dotRadius * 2.2
NSGradient(colors: [blue.withAlphaComponent(0.55), blue.withAlphaComponent(0)])!
    .draw(in: NSBezierPath(ovalIn: NSRect(x: dot.x - glowRadius, y: dot.y - glowRadius,
                                          width: glowRadius * 2, height: glowRadius * 2)),
          relativeCenterPosition: .zero)
blue.setFill()
NSBezierPath(ovalIn: NSRect(x: dot.x - dotRadius, y: dot.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)).fill()

// 專案名橫條
let bar = NSRect(x: pill.minX + 195, y: pill.midY - 20, width: 310, height: 40)
NSColor.white.withAlphaComponent(0.9).setFill()
NSBezierPath(roundedRect: bar, xRadius: 20, yRadius: 20).fill()

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
