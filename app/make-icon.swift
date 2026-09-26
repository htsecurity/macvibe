// Renders MacVibe's app icon into an .iconset folder:  swift make-icon.swift OUT.iconset
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func drawIcon(in rect: NSRect) {
    let s = rect.width / 1024
    // macOS icon grid: 824pt rounded square centred in 1024.
    let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 186 * s, yRadius: 186 * s)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.set()
    NSGradient(colors: [
        NSColor(srgbRed: 0.33, green: 0.47, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.33, blue: 0.96, alpha: 1),
    ])!.draw(in: squircle, angle: -70)
    NSGraphicsContext.restoreGraphicsState()

    // Glass: a soft sheen on the upper half and a bright rim.
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.34), NSColor.white.withAlphaComponent(0.0)])!
        .draw(in: NSRect(x: body.minX, y: body.midY - 40 * s, width: body.width, height: body.height / 2 + 40 * s), angle: 90)
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.35).setStroke()
    let rim = NSBezierPath(roundedRect: body.insetBy(dx: 3 * s, dy: 3 * s), xRadius: 183 * s, yRadius: 183 * s)
    rim.lineWidth = 5 * s
    rim.stroke()

    let config = NSImage.SymbolConfiguration(pointSize: 400 * s, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "cup.and.heat.waves.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let size = symbol.size
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowBlurRadius = 18 * s
        glow.shadowOffset = NSSize(width: 0, height: -6 * s)
        glow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        glow.set()
        symbol.draw(in: NSRect(x: body.midX - size.width / 2, y: body.midY - size.height / 2 - 8 * s,
                               width: size.width, height: size.height))
        NSGraphicsContext.restoreGraphicsState()
    }
}

let sizes: [(String, Int)] = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
    ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024),
]
for (name, px) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
