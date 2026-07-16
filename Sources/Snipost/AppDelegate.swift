import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeys = HotkeyManager()
    private var editors: [EditorWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "camera.viewfinder",
                accessibilityDescription: "Snipost"
            )
        }
        statusItem.menu = buildMenu()

        let optShift = UInt32(optionKey | shiftKey)
        hotkeys.register(keyCode: UInt32(kVK_ANSI_S), modifiers: optShift) { [weak self] in
            self?.capture(.area)
        }
        hotkeys.register(keyCode: UInt32(kVK_ANSI_W), modifiers: optShift) { [weak self] in
            self?.capture(.window)
        }
        hotkeys.register(keyCode: UInt32(kVK_ANSI_F), modifiers: optShift) { [weak self] in
            self?.capture(.screen)
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let area = NSMenuItem(title: "Capture Area", action: #selector(captureArea), keyEquivalent: "s")
        area.keyEquivalentModifierMask = [.option, .shift]
        area.target = self
        menu.addItem(area)

        let window = NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: "w")
        window.keyEquivalentModifierMask = [.option, .shift]
        window.target = self
        menu.addItem(window)

        let screen = NSMenuItem(title: "Capture Full Screen", action: #selector(captureScreen), keyEquivalent: "f")
        screen.keyEquivalentModifierMask = [.option, .shift]
        screen.target = self
        menu.addItem(screen)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Snipost", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    @objc private func captureArea() { capture(.area) }
    @objc private func captureWindow() { capture(.window) }
    @objc private func captureScreen() { capture(.screen) }

    private func capture(_ kind: CaptureKind) {
        CaptureService.capture(kind) { [weak self] image in
            guard let self, let image else { return }
            self.openEditor(with: image)
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
