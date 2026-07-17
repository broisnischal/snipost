import AppKit
import CoreGraphics

/// Draws macOS-style cursors as vector paths so they stay crisp at any size
/// (the real NSCursor bitmaps are only 64px and blur when scaled up — and the
/// arrow isn't even available outside a WindowServer session).
enum CursorArt {
    /// `tip` is the cursor hotspot in CG (bottom-up) canvas coordinates.
    static func draw(_ style: CursorStyle, in context: CGContext, tip: CGPoint, size: CGFloat) {
        switch style {
        case .none:
            return
        case .arrow:
            drawPolygon(
                classicArrowPoints,
                in: context,
                tip: tip,
                size: size,
                fill: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
                stroke: CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            )
        case .crosshair:
            drawPolygon(
                crosshairPoints,
                in: context,
                tip: tip,
                size: size,
                fill: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                stroke: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            )
        case .iBeam:
            drawPolygon(
                iBeamPoints,
                in: context,
                tip: tip,
                size: size,
                fill: CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                stroke: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            )
        case .pointingHand:
            drawSystemHand(in: context, tip: tip, size: size)
        }
    }

    // Classic macOS pointer, unit coordinates with y down and the tip at (0, 0).
    private static let classicArrowPoints: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.00),
        CGPoint(x: 0.00, y: 0.85),
        CGPoint(x: 0.19, y: 0.67),
        CGPoint(x: 0.32, y: 0.97),
        CGPoint(x: 0.45, y: 0.92),
        CGPoint(x: 0.33, y: 0.63),
        CGPoint(x: 0.60, y: 0.63),
    ]

    // Plus shape centered on (0, 0), half-length 0.5, half-thickness 0.09.
    private static let crosshairPoints: [CGPoint] = {
        let t: CGFloat = 0.09
        let l: CGFloat = 0.5
        return [
            CGPoint(x: -t, y: -l), CGPoint(x: t, y: -l), CGPoint(x: t, y: -t),
            CGPoint(x: l, y: -t), CGPoint(x: l, y: t), CGPoint(x: t, y: t),
            CGPoint(x: t, y: l), CGPoint(x: -t, y: l), CGPoint(x: -t, y: t),
            CGPoint(x: -l, y: t), CGPoint(x: -l, y: -t), CGPoint(x: -t, y: -t),
        ]
    }()

    // Text I-beam centered on (0, 0): stem plus top and bottom serifs.
    private static let iBeamPoints: [CGPoint] = {
        let stem: CGFloat = 0.07
        let serif: CGFloat = 0.22
        let cap: CGFloat = 0.10
        return [
            CGPoint(x: -serif, y: -0.5), CGPoint(x: serif, y: -0.5),
            CGPoint(x: serif, y: -0.5 + cap), CGPoint(x: stem, y: -0.5 + cap),
            CGPoint(x: stem, y: 0.5 - cap), CGPoint(x: serif, y: 0.5 - cap),
            CGPoint(x: serif, y: 0.5), CGPoint(x: -serif, y: 0.5),
            CGPoint(x: -serif, y: 0.5 - cap), CGPoint(x: -stem, y: 0.5 - cap),
            CGPoint(x: -stem, y: -0.5 + cap), CGPoint(x: -serif, y: -0.5 + cap),
        ]
    }()

    private static func drawPolygon(
        _ unitPoints: [CGPoint],
        in context: CGContext,
        tip: CGPoint,
        size: CGFloat,
        fill: CGColor,
        stroke: CGColor
    ) {
        // Unit points are y-down; flip into CG's bottom-up space around the tip.
        var transform = CGAffineTransform(translationX: tip.x, y: tip.y)
            .scaledBy(x: size, y: -size)
        let path = CGMutablePath()
        path.addLines(between: unitPoints, transform: transform)
        path.closeSubpath()

        context.saveGState()
        context.setLineJoin(.round)
        context.setLineWidth(size * 0.055)
        context.setStrokeColor(stroke)
        context.addPath(path)
        context.strokePath()
        context.setFillColor(fill)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    private static func drawSystemHand(in context: CGContext, tip: CGPoint, size: CGFloat) {
        let image = NSCursor.pointingHand.image
        guard image.size.width > 0 else { return }
        let aspect = image.size.width / image.size.height
        let rect = CGRect(
            x: tip.x - size * aspect * 0.3,
            y: tip.y - size,
            width: size * aspect,
            height: size
        )
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high.rawValue]
        )
        NSGraphicsContext.restoreGraphicsState()
    }
}
