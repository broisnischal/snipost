import CoreGraphics
import CoreImage

enum ImageFilter: String, CaseIterable, Identifiable {
    case none = "None"
    case vivid = "Vivid"
    case warm = "Warm"
    case cool = "Cool"
    case mono = "Mono"
    case pixel = "Pixel"
    case matrix = "Matrix"
    case comic = "Comic"

    var id: String { rawValue }
}

enum ImageFilters {
    private static let context = CIContext()

    /// Applies the filter to the screenshot itself, before compositing.
    static func apply(_ filter: ImageFilter, to image: CGImage) -> CGImage {
        guard filter != .none else { return image }
        var ci = CIImage(cgImage: image)

        switch filter {
        case .none:
            break
        case .vivid:
            ci = ci.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.4,
                kCIInputContrastKey: 1.05,
            ])
        case .warm:
            ci = ci.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 4600, y: 0),
            ])
        case .cool:
            ci = ci.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 8800, y: 0),
            ])
        case .mono:
            ci = ci.applyingFilter("CIPhotoEffectMono")
        case .pixel:
            let extent = ci.extent
            let scale = max(6, min(extent.width, extent.height) / 72)
            ci = ci.applyingFilter("CIPixellate", parameters: [
                kCIInputScaleKey: scale,
                kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY),
            ]).cropped(to: extent)
        case .matrix:
            ci = ci.applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: 0.15, green: 1.0, blue: 0.4),
                kCIInputIntensityKey: 1.0,
            ])
            ci = ci.applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.25,
                kCIInputBrightnessKey: -0.05,
            ])
        case .comic:
            let extent = ci.extent
            ci = ci.applyingFilter("CIComicEffect").cropped(to: extent)
        }

        return context.createCGImage(ci, from: ci.extent) ?? image
    }
}
