import CoreGraphics

struct RGB: Equatable, Hashable {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
}

struct GradientPreset: Equatable, Hashable, Identifiable {
    let id: String
    let name: String
    let colors: [RGB]

    static let all: [GradientPreset] = [
        GradientPreset(id: "indigo", name: "Indigo", colors: [RGB(r: 0.35, g: 0.34, b: 0.84), RGB(r: 0.61, g: 0.35, b: 0.71)]),
        GradientPreset(id: "ocean", name: "Ocean", colors: [RGB(r: 0.13, g: 0.59, b: 0.95), RGB(r: 0.00, g: 0.85, b: 0.79)]),
        GradientPreset(id: "sunset", name: "Sunset", colors: [RGB(r: 0.98, g: 0.45, b: 0.42), RGB(r: 0.99, g: 0.76, b: 0.29)]),
        GradientPreset(id: "candy", name: "Candy", colors: [RGB(r: 0.93, g: 0.28, b: 0.60), RGB(r: 0.55, g: 0.35, b: 0.96)]),
        GradientPreset(id: "forest", name: "Forest", colors: [RGB(r: 0.06, g: 0.55, b: 0.44), RGB(r: 0.51, g: 0.79, b: 0.30)]),
        GradientPreset(id: "graphite", name: "Graphite", colors: [RGB(r: 0.17, g: 0.18, b: 0.21), RGB(r: 0.33, g: 0.35, b: 0.40)]),
        GradientPreset(id: "paper", name: "Paper", colors: [RGB(r: 0.96, g: 0.96, b: 0.97), RGB(r: 0.89, g: 0.90, b: 0.93)]),
        GradientPreset(id: "ink", name: "Ink", colors: [RGB(r: 0.07, g: 0.07, b: 0.09), RGB(r: 0.13, g: 0.13, b: 0.16)]),
    ]
}

enum BackgroundStyle: Equatable, Hashable {
    /// Gradient derived from the screenshot's own edge colors — the default, zero-click look.
    case auto
    case preset(GradientPreset)
    case transparent
}

enum AspectPreset: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case wide = "16:9"
    case square = "1:1"
    case portrait = "4:5"
    case classic = "4:3"

    var id: String { rawValue }

    /// Target width/height ratio; nil means follow the screenshot's own shape.
    var ratio: CGFloat? {
        switch self {
        case .auto: return nil
        case .wide: return 16.0 / 9.0
        case .square: return 1.0
        case .portrait: return 4.0 / 5.0
        case .classic: return 4.0 / 3.0
        }
    }
}

struct BeautifySettings {
    var background: BackgroundStyle = .auto
    /// Padding as a fraction of the screenshot's larger dimension, so the
    /// background "auto-grows" with the image instead of being a fixed border.
    var paddingFraction: CGFloat = 0.09
    var cornerRadius: CGFloat = 14
    var shadowOpacity: CGFloat = 0.45
    var aspect: AspectPreset = .auto
}
