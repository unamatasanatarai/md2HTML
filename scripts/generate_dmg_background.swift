import AppKit

// Generates Resources/dmg_background.png (660×400) and @2x, styled to match the app icon:
// cool off-white surfaces, slate type, and the icon's blue accent.
//
// Geometry must match scripts/build_dmg.sh: window 660×400 pt, icons 100 pt,
// app icon centred at (180, 200), Applications at (480, 200) — top-left origin.
//
// Usage (from the repo root):
//   swiftc scripts/generate_dmg_background.swift -o /tmp/gen_dmg_bg && /tmp/gen_dmg_bg

let width: CGFloat = 660
let height: CGFloat = 400
let appCenter = CGPoint(x: 180, y: 200)
let applicationsCenter = CGPoint(x: 480, y: 200)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    return NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// Palette sampled from the icon.
let surfaceTop = rgb(0xF8F9FD)
let surfaceBottom = rgb(0xE8EBF4)
let slate = rgb(0x2B2F3A)
let slateMuted = rgb(0x6B7181)
let blue = rgb(0x2F7BFF)
let blueDeep = rgb(0x1A5CF0)

func drawBackground(in cg: CGContext) {
    // Base: soft vertical gradient.
    NSGradient(starting: surfaceTop, ending: surfaceBottom)!
        .draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: -90)

    // Ambient glows: blue lower-right, slate upper-left.
    func glow(_ center: CGPoint, _ radius: CGFloat, _ color: NSColor) {
        NSGradient(colors: [color, color.withAlphaComponent(0)])!
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
    }
    glow(CGPoint(x: 560, y: 360), 340, blue.withAlphaComponent(0.13))
    glow(CGPoint(x: 90, y: 30), 300, rgb(0x5A6275, 0.07))
    glow(CGPoint(x: 330, y: 200), 260, NSColor.white.withAlphaComponent(0.55))

    // Dot grid, fading out from the centre so the edges stay calm.
    let spacing: CGFloat = 18
    var y: CGFloat = spacing / 2
    while y < height {
        var x: CGFloat = spacing / 2
        while x < width {
            let dx = (x - width / 2) / (width / 2), dy = (y - height / 2) / (height / 2)
            let fade = max(0, 1 - sqrt(dx * dx + dy * dy) * 0.85)
            if fade > 0.02 {
                cg.setFillColor(slate.withAlphaComponent(0.07 * fade).cgColor)
                cg.fillEllipse(in: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5))
            }
            x += spacing
        }
        y += spacing
    }
}

/// Frosted card behind each icon, tall enough to hold Finder's label underneath it.
func drawCard(at center: CGPoint, in cg: CGContext) {
    let rect = CGRect(x: center.x - 78, y: center.y - 78, width: 156, height: 164)
    let path = CGPath(roundedRect: rect, cornerWidth: 22, cornerHeight: 22, transform: nil)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 8), blur: 26, color: rgb(0x1B2340, 0.10).cgColor)
    cg.addPath(path)
    cg.setFillColor(NSColor.white.withAlphaComponent(0.72).cgColor)
    cg.fillPath()
    cg.restoreGState()

    cg.addPath(path)
    cg.setStrokeColor(NSColor.white.cgColor)
    cg.setLineWidth(1)
    cg.strokePath()

    cg.addPath(CGPath(roundedRect: rect.insetBy(dx: -0.5, dy: -0.5), cornerWidth: 22.5, cornerHeight: 22.5, transform: nil))
    cg.setStrokeColor(rgb(0x1B2340, 0.06).cgColor)
    cg.setLineWidth(0.5)
    cg.strokePath()
}

/// Gently arched gradient arrow from the app card to the Applications card.
func drawArrow(in cg: CGContext) {
    let start = CGPoint(x: appCenter.x + 92, y: appCenter.y - 4)
    let end = CGPoint(x: applicationsCenter.x - 98, y: applicationsCenter.y - 4)
    let control = CGPoint(x: (start.x + end.x) / 2, y: appCenter.y - 34)

    let shaft = CGMutablePath()
    shaft.move(to: start)
    shaft.addQuadCurve(to: end, control: control)

    // Arrowhead aligned with the curve's end tangent.
    let angle = atan2(end.y - control.y, end.x - control.x)
    let headLength: CGFloat = 11, spread: CGFloat = .pi / 5.2
    let head = CGMutablePath()
    head.move(to: CGPoint(x: end.x - headLength * cos(angle - spread), y: end.y - headLength * sin(angle - spread)))
    head.addLine(to: end)
    head.addLine(to: CGPoint(x: end.x - headLength * cos(angle + spread), y: end.y - headLength * sin(angle + spread)))

    let stroked = CGMutablePath()
    stroked.addPath(shaft.copy(strokingWithWidth: 3.2, lineCap: .round, lineJoin: .round, miterLimit: 4))
    stroked.addPath(head.copy(strokingWithWidth: 3.2, lineCap: .round, lineJoin: .round, miterLimit: 4))

    // Soft blue glow under the arrow.
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 3), blur: 10, color: blue.withAlphaComponent(0.35).cgColor)
    cg.addPath(stroked)
    cg.setFillColor(blue.cgColor)
    cg.fillPath()
    cg.restoreGState()

    // Gradient fill: light blue to the icon's deep blue.
    cg.saveGState()
    cg.addPath(stroked)
    cg.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [rgb(0x7DB1FF).cgColor, blueDeep.cgColor] as CFArray,
        locations: [0, 1]
    )!
    cg.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    cg.restoreGState()
}

func drawText() {
    func draw(_ string: String, y: CGFloat, font: NSFont, color: NSColor, kern: CGFloat = 0) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let text = NSAttributedString(string: string, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style, .kern: kern,
        ])
        let size = text.size()
        text.draw(in: CGRect(x: 0, y: y, width: width, height: ceil(size.height)))
    }

    // Wordmark: "md2" in slate, "HTML" in blue — the icon's two colours.
    let wordmark = NSMutableAttributedString(string: "md2", attributes: [
        .font: NSFont.systemFont(ofSize: 26, weight: .bold), .foregroundColor: slate, .kern: -0.4,
    ])
    wordmark.append(NSAttributedString(string: "HTML", attributes: [
        .font: NSFont.systemFont(ofSize: 26, weight: .bold), .foregroundColor: blueDeep, .kern: -0.4,
    ]))
    let size = wordmark.size()
    wordmark.draw(at: CGPoint(x: (width - size.width) / 2, y: 34))

    draw("Markdown in, HTML out — live.", y: 70, font: .systemFont(ofSize: 12.5, weight: .regular), color: slateMuted)
    draw("DRAG TO APPLICATIONS TO INSTALL", y: 330, font: .systemFont(ofSize: 10, weight: .semibold),
         color: slateMuted.withAlphaComponent(0.85), kern: 1.6)
}

func generate(scale: CGFloat, outputPath: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    let bitmapContext = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = bitmapContext.cgContext
    // Top-left origin for everything, including AppKit text drawing.
    cg.translateBy(x: 0, y: height)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

    drawBackground(in: cg)
    drawCard(at: appCenter, in: cg)
    drawCard(at: applicationsCenter, in: cg)
    drawArrow(in: cg)
    drawText()

    // Hairline frame.
    cg.setStrokeColor(rgb(0x1B2340, 0.08).cgColor)
    cg.setLineWidth(1)
    cg.stroke(CGRect(x: 0.5, y: 0.5, width: width - 1, height: height - 1))

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
    try! data.write(to: URL(fileURLWithPath: outputPath))
    print("Generated: \(outputPath) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
}

generate(scale: 1, outputPath: "Resources/dmg_background.png")
generate(scale: 2, outputPath: "Resources/dmg_background@2x.png")
