import AppKit
import CoreGraphics

/// Pure CoreGraphics compositor: background → shadow → rounded screenshot.
/// Fast enough to re-render live while dragging sliders.
enum BeautifyRenderer {
    static func render(
        image: CGImage,
        settings: BeautifySettings,
        autoColors: [RGB],
        maxDimension: CGFloat? = nil
    ) -> CGImage? {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let padding = settings.paddingFraction * max(imageWidth, imageHeight)

        // Canvas grows around the screenshot; aspect presets expand it further
        // (never crop) to hit platform ratios.
        var canvasWidth = imageWidth + padding * 2
        var canvasHeight = imageHeight + padding * 2
        if let ratio = settings.aspect.ratio {
            if canvasWidth / canvasHeight < ratio {
                canvasWidth = canvasHeight * ratio
            } else {
                canvasHeight = canvasWidth / ratio
            }
        }

        var scale: CGFloat = 1
        if let maxDimension, max(canvasWidth, canvasHeight) > maxDimension {
            scale = maxDimension / max(canvasWidth, canvasHeight)
        }

        let pixelWidth = Int((canvasWidth * scale).rounded())
        let pixelHeight = Int((canvasHeight * scale).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        drawBackground(in: context, size: CGSize(width: pixelWidth, height: pixelHeight), settings: settings, autoColors: autoColors)

        let drawWidth = imageWidth * scale
        let drawHeight = imageHeight * scale
        let imageRect = CGRect(
            x: (CGFloat(pixelWidth) - drawWidth) / 2,
            y: (CGFloat(pixelHeight) - drawHeight) / 2,
            width: drawWidth,
            height: drawHeight
        )
        let radius = min(settings.cornerRadius * scale, min(drawWidth, drawHeight) / 2)
        let path = CGPath(
            roundedRect: imageRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        // Shadow pass: fill the rounded rect with the shadow enabled, then draw
        // the clipped screenshot on top.
        if settings.shadowOpacity > 0.01 {
            context.saveGState()
            let blur = 0.035 * max(imageWidth, imageHeight) * scale
            let offsetY = -0.012 * max(imageWidth, imageHeight) * scale
            context.setShadow(
                offset: CGSize(width: 0, height: offsetY),
                blur: blur,
                color: CGColor(red: 0, green: 0, blue: 0, alpha: settings.shadowOpacity)
            )
            context.addPath(path)
            context.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1))
            context.fillPath()
            context.restoreGState()
        }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.interpolationQuality = .high
        context.draw(image, in: imageRect)
        context.restoreGState()

        return context.makeImage()
    }

    private static func drawBackground(
        in context: CGContext,
        size: CGSize,
        settings: BeautifySettings,
        autoColors: [RGB]
    ) {
        let colors: [RGB]
        switch settings.background {
        case .auto:
            colors = autoColors
        case .preset(let preset):
            colors = preset.colors
        case .transparent:
            return
        }

        let cgColors = colors.map { CGColor(red: $0.r, green: $0.g, blue: $0.b, alpha: 1) }
        guard cgColors.count >= 2,
              let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors as CFArray,
                locations: [0, 1]
              )
        else {
            if let first = cgColors.first {
                context.setFillColor(first)
                context.fill(CGRect(origin: .zero, size: size))
            }
            return
        }

        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size.height),
            end: CGPoint(x: size.width, y: 0),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
}
