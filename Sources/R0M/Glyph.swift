import AppKit
import SwiftUI

enum Glyph {
    static let appIcon: NSImage = Bundle.main.image(forResource: "R0M") ?? NSImage(systemSymbolName: "diamond.fill", accessibilityDescription: nil) ?? NSImage()

    static let menuBar: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let cx = rect.midX, cy = rect.midY
            let gem = NSBezierPath()
            gem.move(to: CGPoint(x: cx, y: cy + 8))
            gem.line(to: CGPoint(x: cx + 6.4, y: cy))
            gem.line(to: CGPoint(x: cx, y: cy - 8))
            gem.line(to: CGPoint(x: cx - 6.4, y: cy))
            gem.close()
            gem.lineWidth = 1.5
            gem.lineJoinStyle = .round
            NSColor.black.setStroke()
            gem.stroke()

            let pulse = NSBezierPath()
            let pts: [(CGFloat, CGFloat)] = [(-8.5, 0), (-3, 0), (-1.8, 1.8), (-0.3, -3.6), (1.4, 3.8), (2.6, 0), (8.5, 0)]
            for (i, p) in pts.enumerated() {
                let pt = CGPoint(x: cx + p.0, y: cy + p.1)
                i == 0 ? pulse.move(to: pt) : pulse.line(to: pt)
            }
            pulse.lineWidth = 1.5
            pulse.lineCapStyle = .round
            pulse.lineJoinStyle = .round
            pulse.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
