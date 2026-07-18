import AppKit
import Foundation

/// Every capture's original PNG, kept in Application Support and pruned to the
/// newest 200. Filenames sort chronologically.
enum HistoryStore {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Snipost/History", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func save(_ image: CGImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let url = directory.appendingPathComponent("\(formatter.string(from: Date())).png")
        Task.detached(priority: .utility) {
            _ = ImageWriter.write(image, to: url.path)
            prune()
        }
    }

    static func list() -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return items
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func clear() {
        for url in list() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func prune(keep: Int = 200) {
        let items = list()
        guard items.count > keep else { return }
        for url in items.dropFirst(keep) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
