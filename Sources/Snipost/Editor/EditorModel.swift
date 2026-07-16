import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class EditorModel: ObservableObject {
    let source: CGImage
    let autoColors: [RGB]

    @Published var settings = BeautifySettings() {
        didSet { renderPreview() }
    }
    @Published var preview: NSImage?
    @Published var justCopied = false
    @Published var lastSaveMessage: String?

    init(source: CGImage) {
        self.source = source
        self.autoColors = ColorAnalysis.autoGradient(for: source)
        renderPreview()
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
            image: source,
            settings: settings,
            autoColors: autoColors,
            maxDimension: 1400
        ) else { return }
        preview = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
    }

    func renderFull() -> CGImage? {
        BeautifyRenderer.render(image: source, settings: settings, autoColors: autoColors)
    }

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
        let url = desktop.appendingPathComponent(Self.defaultFilename())
        if HeadlessRender.writePNG(full, to: url.path) {
            flashSaveMessage("Saved to Desktop")
        }
    }

    func saveAs() {
        guard let full = renderFull() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = Self.defaultFilename()
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            if HeadlessRender.writePNG(full, to: url.path) {
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

    private static func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Snipost \(formatter.string(from: Date())).png"
    }
}
