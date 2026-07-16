import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// CLI entry points so the render pipeline can be exercised (and eyeballed)
/// without any UI — used for development and CI.
enum HeadlessRender {
    static func beautify(inputPath: String, outputPath: String) {
        let url = URL(fileURLWithPath: inputPath)
        guard let image = CaptureService.loadCGImage(at: url) else {
            fputs("snipost: could not read image at \(inputPath)\n", stderr)
            exit(1)
        }
        renderAndWrite(image: image, outputPath: outputPath)
    }

    static func selftest(outputPath: String) {
        guard let fake = makeFakeWindowScreenshot(width: 900, height: 600) else {
            fputs("snipost: failed to draw synthetic screenshot\n", stderr)
            exit(1)
        }
        // Keep the raw input next to the output for comparison.
        let rawPath = (outputPath as NSString).deletingPathExtension + "-raw.png"
        _ = writePNG(fake, to: rawPath)
        renderAndWrite(image: fake, outputPath: outputPath)
    }

    private static func renderAndWrite(image: CGImage, outputPath: String) {
        let settings = BeautifySettings()
        let autoColors = ColorAnalysis.autoGradient(for: image)
        guard let output = BeautifyRenderer.render(image: image, settings: settings, autoColors: autoColors),
              writePNG(output, to: outputPath)
        else {
            fputs("snipost: render failed\n", stderr)
            exit(1)
        }
        print("wrote \(outputPath) (\(output.width)x\(output.height))")
    }

    static func writePNG(_ image: CGImage, to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    /// Draws a plausible dark-themed app window so the auto-gradient and
    /// compositor have something realistic to chew on.
    private static func makeFakeWindowScreenshot(width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let w = CGFloat(width)
        let h = CGFloat(height)

        // Window body: dark editor purple
        ctx.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Title bar (top of image = high y in CG coordinates)
        ctx.setFillColor(CGColor(red: 0.16, green: 0.16, blue: 0.23, alpha: 1))
        ctx.fill(CGRect(x: 0, y: h - 44, width: w, height: 44))

        // Traffic lights
        let lights: [CGColor] = [
            CGColor(red: 1.00, green: 0.38, blue: 0.35, alpha: 1),
            CGColor(red: 1.00, green: 0.74, blue: 0.18, alpha: 1),
            CGColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1),
        ]
        for (i, light) in lights.enumerated() {
            ctx.setFillColor(light)
            ctx.fillEllipse(in: CGRect(x: 16 + CGFloat(i) * 22, y: h - 28, width: 13, height: 13))
        }

        // Fake code lines
        let lineColors: [CGColor] = [
            CGColor(red: 0.55, green: 0.65, blue: 0.98, alpha: 1),
            CGColor(red: 0.95, green: 0.55, blue: 0.66, alpha: 1),
            CGColor(red: 0.55, green: 0.85, blue: 0.70, alpha: 1),
            CGColor(red: 0.80, green: 0.75, blue: 0.50, alpha: 1),
        ]
        var y = h - 84
        var i = 0
        while y > 32 {
            let indent: CGFloat = [0, 24, 48, 24][i % 4]
            let lineWidth = w * [0.42, 0.61, 0.33, 0.52][i % 4] - indent
            let rect = CGRect(x: 32 + indent, y: y, width: lineWidth, height: 12)
            let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            ctx.setFillColor(lineColors[i % lineColors.count])
            ctx.addPath(path)
            ctx.fillPath()
            y -= 28
            i += 1
        }

        return ctx.makeImage()
    }
}
