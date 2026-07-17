import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section("Shortcuts") {
                ForEach(HotkeyAction.allCases, id: \.rawValue) { action in
                    HotkeyRow(action: action)
                }
            }

            Section("After capture") {
                Toggle("Open the editor", isOn: $prefs.openEditorAfterCapture)
                Toggle("Copy beautified image to clipboard", isOn: $prefs.autoCopy)
                Toggle("Save to Desktop automatically", isOn: $prefs.autoSaveToDesktop)
                Text(prefs.openEditorAfterCapture
                    ? "The editor opens after every capture so you can tweak before exporting."
                    : "Instant mode: captures are beautified with default settings and copied/saved right away — no editor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 360)
    }
}

private struct HotkeyRow: View {
    let action: HotkeyAction

    @ObservedObject private var prefs = Preferences.shared
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(action.title)
            Spacer()
            Button(recording ? "Press shortcut… (Esc cancels)" : prefs.hotkey(for: action).display) {
                recording ? stop() : start()
            }
        }
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                stop()
                return nil
            }
            if let hotkey = Hotkey(event: event) {
                Preferences.shared.setHotkey(hotkey, for: action)
                stop()
            } else {
                NSSound.beep() // needs ⌘, ⌥, or ⌃
            }
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController.make()

    private static func make() -> SettingsWindowController {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Snipost Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        return SettingsWindowController(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true { window?.center() }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
