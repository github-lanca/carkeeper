import AppKit
import CoreGraphics

let S: CGFloat = 1024
/// 输出目录：默认为脚本所在目录，可用第一个命令行参数覆盖
/// 用法：swift Tools/gen_icons.swift [输出目录]
let outDir: String = {
    if CommandLine.arguments.count > 1 { return CommandLine.arguments[1] }
    let url = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    return url.path
}()

func makeContext() -> CGContext {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)
    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)
    return ctx
}

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return CGColor(colorSpace: cs, components: [r, g, b, a])!
}

func paintGradient(_ ctx: CGContext, _ c1: UInt32, _ c2: UInt32,
                   from p1: CGPoint, to p2: CGPoint) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let g = CGGradient(colorsSpace: cs, colors: [rgb(c1), rgb(c2)] as CFArray,
                       locations: [0, 1])!
    ctx.drawLinearGradient(g, start: p1, end: p2, options: [])
}

func save(_ ctx: CGContext, _ name: String) {
    guard let img = ctx.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: img)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: outDir + "/" + name))
    print("wrote \(name)")
}

func roundify(_ name: String, _ outName: String) {
    guard let img = NSImage(contentsOfFile: outDir + "/" + name) else { return }
    var r = CGRect(x: 0, y: 0, width: S, height: S)
    guard let cg = img.cgImage(forProposedRect: &r, context: nil, hints: nil) else { return }
    let ctx = makeContext()
    ctx.setFillColor(rgb(0xEDEDF0))
    ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
    let radius = S * 0.2237
    let path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
                      cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path)
    ctx.clip()
    ctx.saveGState()
    ctx.translateBy(x: 0, y: S)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: S, height: S))
    ctx.restoreGState()
    save(ctx, outName)
}

// ─────────── 归一化车侧影（车头朝右） ───────────
func carSide(_ rect: CGRect) -> CGPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
    let path = CGMutablePath()
    path.move(to: p(0.00, 0.86))
    path.addLine(to: p(0.00, 0.54))
    path.addCurve(to: p(0.11, 0.39), control1: p(0.00, 0.44), control2: p(0.04, 0.39))
    path.addLine(to: p(0.26, 0.39))
    path.addLine(to: p(0.375, 0.11))
    path.addCurve(to: p(0.475, 0.07), control1: p(0.395, 0.07), control2: p(0.435, 0.07))
    path.addLine(to: p(0.655, 0.07))
    path.addCurve(to: p(0.785, 0.20), control1: p(0.695, 0.07), control2: p(0.745, 0.12))
    path.addLine(to: p(0.885, 0.31))
    path.addCurve(to: p(1.00, 0.54), control1: p(0.955, 0.35), control2: p(1.00, 0.43))
    path.addLine(to: p(1.00, 0.86))
    path.closeSubpath()
    return path
}

func carGlass(_ rect: CGRect) -> CGPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
    }
    let path = CGMutablePath()
    // 后窗
    path.move(to: p(0.283, 0.362))
    path.addLine(to: p(0.395, 0.138))
    path.addLine(to: p(0.462, 0.138))
    path.addLine(to: p(0.462, 0.362))
    path.closeSubpath()
    // 前窗
    path.move(to: p(0.502, 0.362))
    path.addLine(to: p(0.502, 0.138))
    path.addLine(to: p(0.650, 0.138))
    path.addLine(to: p(0.740, 0.362))
    path.closeSubpath()
    return path
}

func wheelRects(_ rect: CGRect) -> (CGRect, CGRect) {
    let r = rect.width * 0.104
    let cy = rect.minY + 0.86 * rect.height
    func box(_ cx: CGFloat) -> CGRect {
        CGRect(x: rect.minX + cx * rect.width - r, y: cy - r, width: r * 2, height: r * 2)
    }
    return (box(0.235), box(0.775))
}

// ═══════════════ 方案 A：盾牌护车 ═══════════════
func iconA() {
    let ctx = makeContext()
    paintGradient(ctx, 0x16225C, 0x3E2A75,
                  from: CGPoint(x: 0, y: 0), to: CGPoint(x: S, y: S))

    let shield = CGMutablePath()
    shield.move(to: CGPoint(x: 512, y: 232))
    shield.addCurve(to: CGPoint(x: 762, y: 288),
                    control1: CGPoint(x: 606, y: 246), control2: CGPoint(x: 700, y: 268))
    shield.addLine(to: CGPoint(x: 762, y: 526))
    shield.addCurve(to: CGPoint(x: 512, y: 800),
                    control1: CGPoint(x: 762, y: 666), control2: CGPoint(x: 656, y: 748))
    shield.addCurve(to: CGPoint(x: 262, y: 526),
                    control1: CGPoint(x: 368, y: 748), control2: CGPoint(x: 262, y: 666))
    shield.addLine(to: CGPoint(x: 262, y: 288))
    shield.addCurve(to: CGPoint(x: 512, y: 232),
                    control1: CGPoint(x: 324, y: 268), control2: CGPoint(x: 418, y: 246))
    shield.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 30, color: rgb(0x0A0E33, 0.35))
    ctx.addPath(shield)
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.setLineWidth(38)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // ── 车侧影（盾牌内）
    let carRect = CGRect(x: 312, y: 420, width: 400, height: 180)
    ctx.addPath(carSide(carRect))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.addPath(carGlass(carRect))
    ctx.setFillColor(rgb(0x2A2669))
    ctx.fillPath()
    let (aw1, aw2) = wheelRects(carRect)
    for w in [aw1, aw2] {
        ctx.setFillColor(rgb(0x2A2669))
        ctx.fillEllipse(in: w)
    }

    save(ctx, "A-盾牌护车.png")
    roundify("A-盾牌护车.png", "A-预览.png")
}

// ═══════════════ 方案 B：里程环 ═══════════════
func iconB() {
    let ctx = makeContext()
    paintGradient(ctx, 0x11897A, 0x06434F,
                  from: CGPoint(x: 0, y: 0), to: CGPoint(x: S, y: S))

    let cx: CGFloat = 512, cy: CGFloat = 500

    // 刻度
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.95))
    ctx.setLineWidth(18)
    ctx.setLineCap(.round)
    for i in 0..<12 {
        let a = CGFloat(i) * (.pi / 6) - .pi / 2
        ctx.move(to: CGPoint(x: cx + cos(a) * 228, y: cy + sin(a) * 228))
        ctx.addLine(to: CGPoint(x: cx + cos(a) * 266, y: cy + sin(a) * 266))
        ctx.strokePath()
    }
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.setLineWidth(38)
    ctx.strokeEllipse(in: CGRect(x: cx - 292, y: cy - 292, width: 584, height: 584))

    // 车
    let carRect = CGRect(x: 292, y: 396, width: 440, height: 196)
    ctx.addPath(carSide(carRect))
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillPath()
    ctx.addPath(carGlass(carRect))
    ctx.setFillColor(rgb(0x0A5B5E))
    ctx.fillPath()

    let (w1, w2) = wheelRects(carRect)
    for w in [w1, w2] {
        ctx.setFillColor(rgb(0x0A5B5E))
        ctx.fillEllipse(in: w)
        ctx.setStrokeColor(rgb(0xFFFFFF))
        ctx.setLineWidth(13)
        ctx.strokeEllipse(in: w.insetBy(dx: 6.5, dy: 6.5))
    }

    save(ctx, "B-里程环.png")
    roundify("B-里程环.png", "B-预览.png")
}

// ═══════════════ 方案 C：极简清单 ═══════════════
func iconC() {
    let ctx = makeContext()
    paintGradient(ctx, 0xFDFCF9, 0xE7E5DF,
                  from: CGPoint(x: 0, y: 0), to: CGPoint(x: S, y: S))

    let ink = rgb(0x2B2B2E)
    let carRect = CGRect(x: 286, y: 486, width: 452, height: 200)

    ctx.setStrokeColor(ink)
    ctx.setLineWidth(16)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.addPath(carSide(carRect))
    ctx.strokePath()

    ctx.setLineWidth(14)
    ctx.addPath(carGlass(carRect))
    ctx.strokePath()

    let (w1, w2) = wheelRects(carRect)
    for w in [w1, w2] {
        ctx.setLineWidth(15)
        ctx.strokeEllipse(in: w.insetBy(dx: 7.5, dy: 7.5))
    }

    // 蓝色对勾
    let cyCheck: CGFloat = 330
    ctx.setFillColor(rgb(0x0A84FF))
    ctx.fillEllipse(in: CGRect(x: 512 - 66, y: cyCheck - 66, width: 132, height: 132))
    let check = CGMutablePath()
    check.move(to: CGPoint(x: 512 - 29, y: cyCheck + 2))
    check.addLine(to: CGPoint(x: 512 - 9, y: cyCheck + 23))
    check.addLine(to: CGPoint(x: 512 + 31, y: cyCheck - 21))
    ctx.addPath(check)
    ctx.setStrokeColor(rgb(0xFFFFFF))
    ctx.setLineWidth(17)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    save(ctx, "C-极简清单.png")
    roundify("C-极简清单.png", "C-预览.png")
}

iconA()
iconB()
iconC()
print("done")
