import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class EditorModel: ObservableObject {
    let source: CGImage
    let autoColors: [RGB]

    @Published var settings = BeautifySettings() {
        didSet {
            if oldValue.filter != settings.filter {
                filteredSource = ImageFilters.apply(settings.filter, to: source)
            }
            renderPreview()
        }
    }
    @Published var preview: NSImage?
    @Published var justCopied = false
    @Published var lastSaveMessage: String?

    // Custom background colors
    @Published var customSolid: Color = Color(red: 0.35, green: 0.45, blue: 0.85)
    @Published var customGradientStart: Color = Color(red: 0.20, green: 0.35, blue: 0.90)
    @Published var customGradientEnd: Color = Color(red: 0.80, green: 0.30, blue: 0.70)

    // System wallpapers
    @Published private(set) var wallpapers: [Wallpaper] = []
    @Published private(set) var thumbnails: [URL: NSImage] = [:]
    @Published private(set) var selectedWallpaper: URL?

    private(set) var filteredSource: CGImage
    private(set) var backgroundImage: CGImage?

    init(source: CGImage) {
        self.source = source
        self.filteredSource = source
        self.autoColors = ColorAnalysis.autoGradient(for: source)
        renderPreview()
        loadWallpapers()
    }

    var outputSizeText: String {
        guard let full = renderedSize() else { return "" }
        return "\(Int(full.width)) × \(Int(full.height)) px"
    }

    private func renderedSize() -> CGSize? {
        let w = CGFloat(source.width)
        let h = CGFloat(source.height)
        let padding = settings.paddingFraction * max(w, h)
        var cw = w + padding * 2
        var ch = h + padding * 2
        if let ratio = settings.aspect.ratio {
            if cw / ch < ratio { cw = ch * ratio } else { ch = cw / ratio }
        }
        return CGSize(width: cw.rounded(), height: ch.rounded())
    }

    private func renderPreview() {
        guard let rendered = BeautifyRenderer.render(
            image: filteredSource,
            settings: settings,
            autoColors: autoColors,
            backgroundImage: backgroundImage,
            maxDimension: 1400
        ) else { return }
        preview = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
    }

    func renderFull() -> CGImage? {
        BeautifyRenderer.render(
            image: filteredSource,
            settings: settings,
            autoColors: autoColors,
            backgroundImage: backgroundImage
        )
    }

    // MARK: Cursor placement

    /// Called with a click/drag location normalized over the preview (y from the top).
    func placeCursor(atNormalized point: CGPoint) {
        var updated = settings
        if updated.cursor == .none { updated.cursor = .arrow }
        updated.cursorPosition = CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
        settings = updated
    }

    // MARK: Custom background colors

    func applyCustomSolid() {
        settings.background = .solid(Self.rgb(from: customSolid))
    }

    func applyCustomGradient() {
        settings.background = .customGradient(
            Self.rgb(from: customGradientStart),
            Self.rgb(from: customGradientEnd)
        )
    }

    private static func rgb(from color: Color) -> RGB {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .systemBlue
        return RGB(r: ns.redComponent, g: ns.greenComponent, b: ns.blueComponent)
    }

    // MARK: Backgrounds from images

    private func loadWallpapers() {
        Task { @MainActor in
            let found = WallpaperLibrary.systemWallpapers()
            self.wallpapers = found
            for wallpaper in found {
                let url = wallpaper.url
                let cg = await Task.detached(priority: .utility) {
                    WallpaperLibrary.thumbnail(for: url)
                }.value
                if let cg {
                    self.thumbnails[url] = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                }
            }
        }
    }

    func selectWallpaper(_ wallpaper: Wallpaper) {
        selectedWallpaper = wallpaper.url
        Task { @MainActor in
            let url = wallpaper.url
            let image = await Task.detached(priority: .userInitiated) {
                WallpaperLibrary.fullImage(for: url)
            }.value
            guard let image, self.selectedWallpaper == url else { return }
            self.backgroundImage = image
            self.settings.background = .image
        }
    }

    func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                guard let self, let image = CaptureService.loadCGImage(at: url) else { return }
                self.selectedWallpaper = nil
                self.backgroundImage = image
                self.settings.background = .image
            }
        }
    }

    // MARK: Export

    func copyToClipboard() {
        guard let full = renderFull() else { return }
        Clipboard.copy(full)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.justCopied = false
        }
    }

    func saveToDesktop() {
        guard let full = renderFull() else { return }
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let url = desktop.appendingPathComponent(defaultFilename())
        if ImageWriter.write(full, to: url.path, format: settings.exportFormat) {
            flashSaveMessage("Saved to Desktop")
        }
    }

    func saveAs() {
        guard let full = renderFull() else { return }
        let format = settings.exportFormat
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.utType]
        panel.nameFieldStringValue = defaultFilename()
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            if ImageWriter.write(full, to: url.path, format: format) {
                Task { @MainActor in self?.flashSaveMessage("Saved") }
            }
        }
    }

    private func flashSaveMessage(_ message: String) {
        lastSaveMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.lastSaveMessage = nil
        }
    }

    private func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Snipost \(formatter.string(from: Date())).\(settings.exportFormat.fileExtension)"
    }
}
