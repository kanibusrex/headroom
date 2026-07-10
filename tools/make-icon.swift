// Generates Resources/AppIcon.icns. Run from the repo root:
//   swift tools/make-icon.swift && iconutil -c icns AppIcon.iconset -o Resources/AppIcon.icns
import AppKit

let variants: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func render(px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let s = CGFloat(px)
    // macOS icon grid: content squircle sits inside ~10% margins
    let inset = s * 0.098
    let rect = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237

    let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.40, green: 0.18, blue: 0.75, alpha: 1),
    ])!.draw(in: squircle, angle: -65)

    // soft top sheen fading over the full height
    squircle.addClip()
    NSGradient(colors: [
        NSColor(calibratedWhite: 1, alpha: 0),
        NSColor(calibratedWhite: 1, alpha: 0.16),
    ])!.draw(in: rect, angle: 90)

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: rect.width * 0.40, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "wrench.and.screwdriver.fill",
                            accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let natural = symbol.size
        let target = rect.width * 0.58
        let scale = target / max(natural.width, natural.height)
        let w = natural.width * scale
        let h = natural.height * scale
        symbol.draw(
            in: NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h),
            from: .zero, operation: .sourceOver, fraction: 1
        )
    }
    return rep
}

let iconsetURL = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for variant in variants {
    let rep = render(px: variant.px)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: iconsetURL.appendingPathComponent("\(variant.name).png"))
}
print("Wrote AppIcon.iconset (\(variants.count) sizes)")
