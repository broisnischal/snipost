import AppKit
import ImageIO

enum CaptureKind {
    case area
    case window
    case screen
}

/// v0 capture backend: drives the system `screencapture` utility, which gives us
/// the native crosshair/window-picker UI for free. Replaced by ScreenCaptureKit later.
enum CaptureService {
    static func capture(_ kind: CaptureKind, completion: @escaping (CGImage?) -> Void) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snipost-\(UUID().uuidString).png")

        var args = ["-x"] // no shutter sound
        switch kind {
        case .area:
            args.append("-i")
        case .window:
            args += ["-i", "-W"]
        case .screen:
            break
        }
        args.append(tempURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        process.terminationHandler = { _ in
            let image = loadCGImage(at: tempURL) // nil if the user hit Esc
            try? FileManager.default.removeItem(at: tempURL)
            DispatchQueue.main.async { completion(image) }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { completion(nil) }
        }
    }

    static func loadCGImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
