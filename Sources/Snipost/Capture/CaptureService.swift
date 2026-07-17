import AppKit
import ScreenCaptureKit

enum CaptureKind: String, CaseIterable {
    case area
    case window
    case screen
}

/// ScreenCaptureKit backend: the app captures directly (no `screencapture`
/// child process), so Screen Recording permission is checked against Snipost
/// itself and failures surface as a real error we can explain to the user.
enum CaptureService {
    static func capture(_ kind: CaptureKind, completion: @escaping @MainActor (CGImage?) -> Void) {
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let target = targetDisplay(in: content) else {
                    completion(nil)
                    return
                }

                switch kind {
                case .screen:
                    try await Task.sleep(nanoseconds: 250_000_000) // let the menu close
                    completion(try await captureDisplay(target.display, showsCursor: true))

                case .area:
                    let frozen = try await captureDisplay(target.display, showsCursor: false)
                    let viewSize = target.screen.frame.size
                    SelectionOverlayController.begin(
                        mode: .area,
                        screen: target.screen,
                        frozen: frozen,
                        windows: []
                    ) { result in
                        if case .rect(let viewRect) = result {
                            completion(crop(frozen, viewRect: viewRect, viewSize: viewSize))
                        } else {
                            completion(nil)
                        }
                    }

                case .window:
                    let frozen = try await captureDisplay(target.display, showsCursor: false)
                    let viewSize = target.screen.frame.size
                    let pickable = pickableWindows(in: content, display: target.display)
                    SelectionOverlayController.begin(
                        mode: .window,
                        screen: target.screen,
                        frozen: frozen,
                        windows: pickable
                    ) { result in
                        if case .window(let scWindow, let viewRect) = result {
                            Task { @MainActor in
                                // Give the overlay a beat to disappear first.
                                try? await Task.sleep(nanoseconds: 120_000_000)
                                if let isolated = try? await captureWindow(scWindow) {
                                    completion(isolated)
                                } else {
                                    // Clean capture failed — fall back to cropping
                                    // the window's rect out of the frozen screen.
                                    completion(crop(frozen, viewRect: viewRect, viewSize: viewSize))
                                }
                            }
                        } else {
                            completion(nil)
                        }
                    }
                }
            } catch {
                presentPermissionHelp()
                completion(nil)
            }
        }
    }

    // MARK: Display / window selection

    @MainActor
    private static func targetDisplay(in content: SCShareableContent) -> (display: SCDisplay, screen: NSScreen)? {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return nil }
        let screenID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        let display = content.displays.first { $0.displayID == screenID } ?? content.displays.first
        guard let display else { return nil }
        return (display, screen)
    }

    private static func pickableWindows(in content: SCShareableContent, display: SCDisplay) -> [SCWindow] {
        let filtered = content.windows.filter { window in
            window.isOnScreen
                && window.windowLayer == 0
                && window.frame.width > 60 && window.frame.height > 40
                && window.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier
                && window.frame.intersects(display.frame)
        }
        // Hit-testing must go front-to-back; SCShareableContent gives no z-order,
        // but the CG window list does.
        let order = zOrderedWindowIDs()
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return filtered.sorted { (rank[$0.windowID] ?? Int.max) < (rank[$1.windowID] ?? Int.max) }
    }

    private static func zOrderedWindowIDs() -> [CGWindowID] {
        guard let info = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return info.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
    }

    // MARK: ScreenCaptureKit captures

    private static func captureDisplay(_ display: SCDisplay, showsCursor: Bool) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(filter.contentRect.width * scale)
        config.height = Int(filter.contentRect.height * scale)
        config.showsCursor = showsCursor
        config.captureResolution = .best
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Must outlive the SCStreamConfiguration: SCK copies the config without
    /// retaining the color, and a temporary (e.g. NSColor.clear.cgColor)
    /// dangles and crashes in CFRetain.
    private static let clearBackground = CGColor(red: 0, green: 0, blue: 0, alpha: 0)

    private static func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(filter.contentRect.width * scale)
        config.height = Int(filter.contentRect.height * scale)
        config.showsCursor = false
        config.captureResolution = .best
        config.backgroundColor = clearBackground
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Maps a selection in overlay-view points back to pixels of the frozen capture.
    private static func crop(_ image: CGImage, viewRect: CGRect, viewSize: CGSize) -> CGImage? {
        let sx = CGFloat(image.width) / viewSize.width
        let sy = CGFloat(image.height) / viewSize.height
        let pixelRect = CGRect(
            x: viewRect.minX * sx,
            y: (viewSize.height - viewRect.maxY) * sy, // CGImage rows start at the top
            width: viewRect.width * sx,
            height: viewRect.height * sy
        ).integral
        return image.cropping(to: pixelRect)
    }

    @MainActor
    private static func presentPermissionHelp() {
        let alert = NSAlert()
        alert.messageText = "Snipost needs Screen Recording permission"
        alert.informativeText = """
        Enable Snipost in System Settings → Privacy & Security → \
        Screen & System Audio Recording, then quit and reopen Snipost.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    static func loadCGImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
