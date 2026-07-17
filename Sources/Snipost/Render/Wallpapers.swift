import AppKit
import ImageIO

struct Wallpaper: Identifiable, Equatable {
    let url: URL
    let name: String

    var id: URL { url }
}

/// The Mac's own wallpapers, straight from /System/Library/Desktop Pictures —
/// nothing to bundle, and they match what the user already sees on their desktop.
enum WallpaperLibrary {
    static func systemWallpapers(limit: Int = 30) -> [Wallpaper] {
        let directories = [
            URL(fileURLWithPath: "/System/Library/Desktop Pictures"),
            URL(fileURLWithPath: "/System/Library/Desktop Pictures/Solid Colors"),
        ]
        var found: [Wallpaper] = []
        for directory in directories {
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else { continue }
            for url in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let ext = url.pathExtension.lowercased()
                guard ["heic", "jpg", "jpeg", "png", "tif"].contains(ext) else { continue }
                found.append(Wallpaper(url: url, name: url.deletingPathExtension().lastPathComponent))
            }
        }
        return Array(found.prefix(limit))
    }

    static func thumbnail(for url: URL, maxPixel: Int = 112) -> CGImage? {
        downsampled(url: url, maxPixel: maxPixel)
    }

    /// Full-quality load, capped so 6K dynamic wallpapers don't eat memory.
    static func fullImage(for url: URL, maxPixel: Int = 3200) -> CGImage? {
        downsampled(url: url, maxPixel: maxPixel)
    }

    private static func downsampled(url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
