import AppKit
import CoreGraphics
import Foundation

struct HTTPError: LocalizedError {
    let status: Int
    let body: String

    var errorDescription: String? {
        "HTTP \(status): \(body.prefix(200))"
    }
}

enum Net {
    static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPError(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
    }
}

extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}

enum ImageEncoding {
    static func pngData(_ image: CGImage) -> Data? {
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    /// JPEG constrained to a byte budget (Bluesky blobs must stay under ~1 MB):
    /// walk down quality, then resolution, until it fits.
    static func jpegData(_ image: CGImage, maxBytes: Int) -> Data? {
        var current = image
        for _ in 0..<6 {
            for quality in [0.85, 0.7, 0.55] {
                let rep = NSBitmapImageRep(cgImage: current)
                if let data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality]),
                   data.count <= maxBytes {
                    return data
                }
            }
            guard let smaller = downscale(current, factor: 0.75) else { break }
            current = smaller
        }
        return nil
    }

    static func downscale(_ image: CGImage, factor: CGFloat) -> CGImage? {
        let width = Int(CGFloat(image.width) * factor)
        let height = Int(CGFloat(image.height) * factor)
        guard width > 50, height > 50,
              let ctx = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
