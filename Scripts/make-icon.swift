// Generates Resources/AppIcon.icns: an indigo gradient squircle with a white
// viewfinder + lens glyph. Run: swift Scripts/make-icon.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers

func drawIcon(canvas: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: canvas, height: canvas,
        bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let s = CGFloat(canvas) / 1024.0
    let full = CGFloat(canvas)

    // Squircle plate with the standard macOS icon margin.
    let margin = 100 * s
    let plate = CGRect(x: margin, y: margin, width: full - margin * 2, height: full - margin * 2)
    let platePath = CGPath(roundedRect: plate, cornerWidth: 185 * s, cornerHeight: 185 * s, transform: nil)

    // Soft shadow behind the plate.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 28 * s,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(platePath)
    ctx.setFillColor(CGColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Gradient fill.
    ctx.saveGState()
    ctx.addPath(platePath)
    ctx.clip()
    let colors = [
        CGColor(red: 0.42, green: 0.40, blue: 0.94, alpha: 1),
        CGColor(red: 0.55, green: 0.30, blue: 0.78, alpha: 1),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: plate.minX, y: plate.maxY),
            end: CGPoint(x: plate.maxX, y: plate.minY),
            options: []
        )
    }
    // Radial glow near the top.
    if let glow = CGGradient(colorsSpace: colorSpace, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.25),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0),
    ] as CFArray, locations: [0, 1]) {
        let center = CGPoint(x: full / 2, y: plate.maxY - 40 * s)
        ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: 620 * s, options: [])
    }
    ctx.restoreGState()

    // White glyph: viewfinder corner brackets + lens ring + dot.
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineWidth(46 * s)
    ctx.setLineCap(.round)

    let inset = 280 * s
    let arm = 105 * s
    let minX = inset, maxX = full - inset, minY = inset, maxY = full - inset

    // Corner brackets.
    for (cx, cy, dx, dy) in [
        (minX, maxY, 1.0, -1.0),  // top-left
        (maxX, maxY, -1.0, -1.0), // top-right
        (minX, minY, 1.0, 1.0),   // bottom-left
        (maxX, minY, -1.0, 1.0),  // bottom-right
    ] {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: cx + CGFloat(dx) * arm, y: cy))
        ctx.addLine(to: CGPoint(x: cx, y: cy))
        ctx.addLine(to: CGPoint(x: cx, y: cy + CGFloat(dy) * arm))
        ctx.strokePath()
    }

    // Lens.
    let lensRadius = 128 * s
    ctx.strokeEllipse(in: CGRect(
        x: full / 2 - lensRadius, y: full / 2 - lensRadius,
        width: lensRadius * 2, height: lensRadius * 2
    ))
    let dotRadius = 44 * s
    ctx.fillEllipse(in: CGRect(
        x: full / 2 - dotRadius, y: full / 2 - dotRadius,
        width: dotRadius * 2, height: dotRadius * 2
    ))

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("cannot write \(url.path)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]
for (size, name) in variants {
    guard let image = drawIcon(canvas: size) else { fatalError("draw failed at \(size)") }
    writePNG(image, to: iconset.appendingPathComponent("\(name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(iconutil.terminationStatus == 0 ? "wrote Resources/AppIcon.icns" : "iconutil failed")
