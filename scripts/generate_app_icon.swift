import AppKit

// Builds Resources/AppIcon.icns and Resources/AppIcon.png from the flat source artwork.
//
// The source (Design/AppIcon-source.jpeg, 2048×2048, no alpha) is a finished rounded tile with
// a baked-in shadow on an opaque light background. This script cuts the tile out, masks it to a
// transparent rounded rectangle, and places it on Apple's macOS icon grid (824 px tile on a
// 1024 px canvas) with a soft drop shadow, then renders every iconset size and runs iconutil.
//
// Usage (from the repo root):
//   swiftc scripts/generate_app_icon.swift -o /tmp/generate_app_icon && /tmp/generate_app_icon

let sourcePath = "Design/AppIcon-source.jpeg"
let resourcesDir = "Resources"

/// Square inside the source tile, in source pixels with the origin at the top-left. Measured from
/// the tile's edges (x 268–1866, y 200–1782) and inset ~20 px to drop the source's own rim and shadow.
let sourceCrop = CGRect(x: 287, y: 211, width: 1560, height: 1560)

/// macOS icon grid: 824 px tile, ~22.5% corner radius, centred slightly high to leave room for the shadow.
let canvasSize: CGFloat = 1024
let tileSize: CGFloat = 824
let tileRadius: CGFloat = 185.4

func loadSource() -> CGImage {
    let url = URL(fileURLWithPath: sourcePath)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Cannot read \(sourcePath)")
    }
    guard let cropped = image.cropping(to: sourceCrop) else { fatalError("Crop is outside the source image") }
    return cropped
}

/// Renders the icon at `pixels` × `pixels`, drawing everything in 1024-unit grid coordinates.
func render(_ tile: CGImage, pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    cg.interpolationQuality = .high
    cg.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))

    let scale = CGFloat(pixels) / canvasSize
    cg.scaleBy(x: scale, y: scale)

    let margin = (canvasSize - tileSize) / 2
    let tileRect = CGRect(x: margin, y: margin + 10, width: tileSize, height: tileSize)
    let tilePath = CGPath(roundedRect: tileRect, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)

    // Soft drop shadow (skipped at tiny sizes, where it only muddies the edge).
    if pixels >= 64 {
        cg.saveGState()
        cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.28).cgColor)
        cg.addPath(tilePath)
        cg.setFillColor(NSColor(calibratedWhite: 0.92, alpha: 1).cgColor)
        cg.fillPath()
        cg.restoreGState()
    }

    // Artwork clipped to the rounded tile.
    cg.saveGState()
    cg.addPath(tilePath)
    cg.clip()
    cg.draw(tile, in: tileRect)
    cg.restoreGState()

    // Hairline rim so the light tile keeps its edge on light backgrounds.
    cg.addPath(tilePath)
    cg.setStrokeColor(NSColor.black.withAlphaComponent(0.10).cgColor)
    cg.setLineWidth(2)
    cg.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG encode failed") }
    do { try data.write(to: URL(fileURLWithPath: path)) } catch { fatalError("Write \(path): \(error)") }
}

let tile = loadSource()

let iconset = NSTemporaryDirectory() + "AppIcon-\(UUID().uuidString).iconset"
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(atPath: iconset) }

for points in [16, 32, 128, 256, 512] {
    writePNG(render(tile, pixels: points), to: "\(iconset)/icon_\(points)x\(points).png")
    writePNG(render(tile, pixels: points * 2), to: "\(iconset)/icon_\(points)x\(points)@2x.png")
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "\(resourcesDir)/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed (\(iconutil.terminationStatus))") }

writePNG(render(tile, pixels: 512), to: "\(resourcesDir)/AppIcon.png")
print("Wrote \(resourcesDir)/AppIcon.icns and \(resourcesDir)/AppIcon.png")
