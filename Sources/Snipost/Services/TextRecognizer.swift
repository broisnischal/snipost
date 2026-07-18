import CoreGraphics
import Vision

/// OCR via Apple's Vision framework — ships with macOS, runs on-device, and
/// outperforms Tesseract on screen-rendered text (same engine Shottr/TRex use).
enum TextRecognizer {
    /// Recognized text, top-to-bottom, one line per string. Empty if none.
    static func recognize(in image: CGImage) async -> String {
        await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(cgImage: image)
            try? handler.perform([request])
            return (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }
}
