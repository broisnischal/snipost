import AppKit
import CoreGraphics

/// Derives a background gradient from the screenshot itself: sample the edge
/// pixels (the part that will sit against the background), average them, and
/// build a two-stop gradient around that color.
enum ColorAnalysis {
    struct HSB {
        var h: CGFloat
        var s: CGFloat
        var b: CGFloat
    }

    static func autoGradient(for image: CGImage) -> [RGB] {
        let edge = dominantEdgeColor(of: image)

        // Near-grayscale screenshots (terminals, most app chrome) get a calm
        // slate gradient matched to their brightness instead of a mud-colored one.
        if edge.s < 0.12 {
            if edge.b > 0.65 {
                return [RGB(r: 0.55, g: 0.61, b: 0.72), RGB(r: 0.36, g: 0.42, b: 0.55)]
            } else {
                return [RGB(r: 0.25, g: 0.28, b: 0.38), RGB(r: 0.12, g: 0.13, b: 0.20)]
            }
        }

        let top = HSB(
            h: edge.h,
            s: min(1, max(0.35, edge.s * 1.05)),
            b: min(1, edge.b + 0.28)
        )
        let bottom = HSB(
            h: (edge.h + 0.07).truncatingRemainder(dividingBy: 1),
            s: min(1, max(0.45, edge.s * 1.35)),
            b: max(0.18, edge.b - 0.22)
        )
        return [rgb(from: top), rgb(from: bottom)]
    }

    static func dominantEdgeColor(of image: CGImage) -> HSB {
        let size = 32
        var data = [UInt8](repeating: 0, count: size * size * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &data,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return HSB(h: 0.6, s: 0.4, b: 0.5)
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

        var rSum: CGFloat = 0, gSum: CGFloat = 0, bSum: CGFloat = 0
        var count: CGFloat = 0
        let ring = 3 // sample a 3px ring around the edge of the downscaled image

        for y in 0..<size {
            for x in 0..<size {
                let onEdge = x < ring || x >= size - ring || y < ring || y >= size - ring
                guard onEdge else { continue }
                let i = (y * size + x) * 4
                let alpha = CGFloat(data[i + 3])
                guard alpha > 32 else { continue } // skip transparent (window shadow) pixels
                // un-premultiply
                rSum += CGFloat(data[i]) / alpha
                gSum += CGFloat(data[i + 1]) / alpha
                bSum += CGFloat(data[i + 2]) / alpha
                count += 1
            }
        }

        guard count > 0 else { return HSB(h: 0.6, s: 0.4, b: 0.5) }

        let color = NSColor(
            deviceRed: rSum / count,
            green: gSum / count,
            blue: bSum / count,
            alpha: 1
        )
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        return HSB(h: h, s: s, b: b)
    }

    static func rgb(from hsb: HSB) -> RGB {
        let color = NSColor(hue: hsb.h, saturation: hsb.s, brightness: hsb.b, alpha: 1)
        return RGB(r: color.redComponent, g: color.greenComponent, b: color.blueComponent)
    }
}
