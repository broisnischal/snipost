import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeys = HotkeyManager()
    private var editors: [EditorWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Trigger the system Screen Recording prompt once so the app registers
        // itself in Privacy & Security. Asking on every launch would nag users
        // whose permission state macOS reports lazily.
        let requestedKey = "didRequestScreenAccess"
        if !CGPreflightScreenCaptureAccess(), !UserDefaults.standard.bool(forKey: requestedKey) {
            UserDefaults.standard.set(true, forKey: requestedKey)
            CGRequestScreenCaptureAccess()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "camera.viewfinder",
                accessibilityDescription: "Snipost"
            )
        }

        reloadHotkeysAndMenu()

        NotificationCenter.default.addObserver(
            forName: .snipostHotkeysChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reloadHotkeysAndMenu() }
        }
    }

    private func reloadHotkeysAndMenu() {
        hotkeys.unregisterAll()
        for action in HotkeyAction.allCases {
            let hotkey = Preferences.shared.hotkey(for: action)
            hotkeys.register(keyCode: hotkey.keyCode, modifiers: hotkey.carbonModifiers) { [weak self] in
                self?.perform(action)
            }
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        addCaptureItem(to: menu, title: "Capture Area", hotkeyAction: .area, action: #selector(captureArea))
        addCaptureItem(to: menu, title: "Capture Window", hotkeyAction: .window, action: #selector(captureWindow))
        addCaptureItem(to: menu, title: "Capture Full Screen", hotkeyAction: .screen, action: #selector(captureScreen))
        addCaptureItem(to: menu, title: "Snip to Clipboard", hotkeyAction: .plainArea, action: #selector(plainSnip))

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Snipost", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    private func addCaptureItem(to menu: NSMenu, title: String, hotkeyAction: HotkeyAction, action: Selector) {
        let hotkey = Preferences.shared.hotkey(for: hotkeyAction)
        let item = NSMenuItem(title: title, action: action, keyEquivalent: hotkey.menuKeyEquivalent)
        item.keyEquivalentModifierMask = hotkey.nsModifiers
        item.target = self
        menu.addItem(item)
    }

    @objc private func captureArea() { perform(.area) }
    @objc private func captureWindow() { perform(.window) }
    @objc private func captureScreen() { perform(.screen) }
    @objc private func plainSnip() { perform(.plainArea) }
    @objc private func openSettings() { SettingsWindowController.shared.show() }

    private func perform(_ action: HotkeyAction) {
        CaptureService.capture(action.captureKind) { [weak self] image in
            guard let self, let image else { return }
            if action == .plainArea {
                // Plain snip: the raw screenshot, straight to the clipboard.
                Clipboard.copy(image)
                Toast.show("Copied to clipboard")
            } else {
                self.handleCaptured(image)
            }
        }
    }

    private func handleCaptured(_ image: CGImage) {
        let prefs = Preferences.shared
        if prefs.openEditorAfterCapture {
            openEditor(with: image)
            if prefs.autoCopy {
                autoProcess(image, copy: true, save: false)
            }
        } else {
            // Instant mode: never drop a capture on the floor — copy even if
            // both toggles are off unless the user opted into save-only.
            let copy = prefs.autoCopy || !prefs.autoSaveToDesktop
            autoProcess(image, copy: copy, save: prefs.autoSaveToDesktop)
        }
    }

    /// Beautifies with default settings and copies/saves without the editor.
    private func autoProcess(_ image: CGImage, copy: Bool, save: Bool) {
        let settings = BeautifySettings()
        let autoColors = ColorAnalysis.autoGradient(for: image)
        guard let rendered = BeautifyRenderer.render(image: image, settings: settings, autoColors: autoColors) else {
            return
        }

        var notes: [String] = []
        if copy {
            Clipboard.copy(rendered)
            notes.append("Copied to clipboard")
        }
        if save {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
            let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
            let url = desktop.appendingPathComponent("Snipost \(formatter.string(from: Date())).png")
            if ImageWriter.write(rendered, to: url.path) {
                notes.append("Saved to Desktop")
            }
        }
        if !notes.isEmpty {
            Toast.show(notes.joined(separator: " · "))
        }
    }

    private func openEditor(with image: CGImage) {
        let controller = EditorWindowController(image: image)
        editors.append(controller)

        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)

        if let window = controller.window {
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.editors.removeAll { $0 === controller }
            }
        }
    }
}
