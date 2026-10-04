import AppKit

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

func gradient(_ colors: [NSColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
}

func drawIcon(size S: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: S, height: S))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let cx = S / 2, cy = S / 2

    let inset = S * 0.06
    let rect = CGRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
    let radius = rect.width * 0.2237
    ctx.saveGState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    ctx.drawLinearGradient(gradient([rgb(9, 12, 22), rgb(22, 29, 48)]),
                           start: CGPoint(x: cx, y: rect.maxY), end: CGPoint(x: cx, y: rect.minY), options: [])
    ctx.drawRadialGradient(gradient([rgb(45, 226, 200, 0.22), rgb(45, 226, 200, 0)]),
                           startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                           endCenter: CGPoint(x: cx, y: cy), endRadius: S * 0.46, options: [])
    ctx.restoreGState()

    let h = S * 0.355, w = S * 0.285
    let gem = NSBezierPath()
    gem.move(to: CGPoint(x: cx, y: cy + h))
    gem.line(to: CGPoint(x: cx + w, y: cy))
    gem.line(to: CGPoint(x: cx, y: cy - h))
    gem.line(to: CGPoint(x: cx - w, y: cy))
    gem.close()
    gem.lineJoinStyle = .round

    ctx.saveGState()
    let glow = NSShadow()
    glow.shadowColor = rgb(45, 226, 200, 0.45)
    glow.shadowBlurRadius = S * 0.05
    glow.set()
    rgb(45, 226, 200).setFill()
    gem.fill()
    ctx.restoreGState()

    ctx.saveGState()
    gem.addClip()
    ctx.drawLinearGradient(gradient([rgb(70, 240, 205), rgb(46, 150, 245), rgb(72, 92, 255)]),
                           start: CGPoint(x: cx - w, y: cy + h), end: CGPoint(x: cx + w, y: cy - h), options: [])
    NSColor.black.withAlphaComponent(0.20).setFill()
    NSBezierPath(rect: CGRect(x: cx - w, y: cy - h, width: w, height: 2 * h)).fill()
    ctx.restoreGState()

    let pts: [(CGFloat, CGFloat)] = [(-0.37, 0), (-0.14, 0), (-0.085, 0.075), (-0.015, -0.17),
                                     (0.065, 0.18), (0.12, 0), (0.37, 0)]
    let pulse = NSBezierPath()
    for (i, p) in pts.enumerated() {
        let pt = CGPoint(x: cx + p.0 * S, y: cy + p.1 * S)
        i == 0 ? pulse.move(to: pt) : pulse.line(to: pt)
    }
    pulse.lineWidth = S * 0.05
    pulse.lineCapStyle = .round
    pulse.lineJoinStyle = .round
    ctx.saveGState()
    let drop = NSShadow()
    drop.shadowColor = NSColor.black.withAlphaComponent(0.35)
    drop.shadowBlurRadius = S * 0.02
    drop.shadowOffset = NSSize(width: 0, height: -S * 0.01)
    drop.set()
    NSColor.white.setStroke()
    pulse.stroke()
    ctx.restoreGState()

    img.unlockFocus()
    return img
}

func png(_ image: NSImage, _ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: CGRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./R0M.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let specs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (px, name) in specs {
    let data = png(drawIcon(size: CGFloat(px)), px)
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("wrote \(specs.count) icon sizes to \(outDir)")
