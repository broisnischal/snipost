import AppKit
import Carbon.HIToolbox

extension Notification.Name {
    static let snipostHotkeysChanged = Notification.Name("snipostHotkeysChanged")
}

/// Everything a global shortcut can trigger. `plainArea` is the "just snip and
/// copy" flow: raw screenshot straight to the clipboard, no beautify, no editor.
enum HotkeyAction: String, CaseIterable {
    case area
    case window
    case screen
    case plainArea

    var title: String {
        switch self {
        case .area: return "Capture area"
        case .window: return "Capture window"
        case .screen: return "Capture full screen"
        case .plainArea: return "Snip to clipboard (plain)"
        }
    }

    var captureKind: CaptureKind {
        self == .plainArea ? .area : CaptureKind(rawValue: rawValue)!
    }
}

/// User settings, persisted in UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    /// Off = instant mode: beautify with defaults and copy/save immediately.
    @Published var openEditorAfterCapture: Bool {
        didSet { defaults.set(openEditorAfterCapture, forKey: "openEditorAfterCapture") }
    }
    @Published var autoCopy: Bool {
        didSet { defaults.set(autoCopy, forKey: "autoCopy") }
    }
    @Published var autoSaveToDesktop: Bool {
        didSet { defaults.set(autoSaveToDesktop, forKey: "autoSaveToDesktop") }
    }
    @Published private(set) var hotkeys: [HotkeyAction: Hotkey] = [:]

    static let defaultHotkeys: [HotkeyAction: Hotkey] = [
        .area: Hotkey(keyCode: UInt32(kVK_ANSI_S), carbonModifiers: UInt32(optionKey | shiftKey)),
        .window: Hotkey(keyCode: UInt32(kVK_ANSI_W), carbonModifiers: UInt32(optionKey | shiftKey)),
        .screen: Hotkey(keyCode: UInt32(kVK_ANSI_F), carbonModifiers: UInt32(optionKey | shiftKey)),
        .plainArea: Hotkey(keyCode: UInt32(kVK_ANSI_C), carbonModifiers: UInt32(optionKey | shiftKey)),
    ]

    private init() {
        openEditorAfterCapture = defaults.object(forKey: "openEditorAfterCapture") as? Bool ?? true
        autoCopy = defaults.object(forKey: "autoCopy") as? Bool ?? true
        autoSaveToDesktop = defaults.object(forKey: "autoSaveToDesktop") as? Bool ?? false

        var loaded: [HotkeyAction: Hotkey] = [:]
        for action in HotkeyAction.allCases {
            if let stored = defaults.array(forKey: "hotkey.\(action.rawValue)") as? [Int], stored.count == 2 {
                loaded[action] = Hotkey(keyCode: UInt32(stored[0]), carbonModifiers: UInt32(stored[1]))
            }
        }
        hotkeys = loaded
    }

    func hotkey(for action: HotkeyAction) -> Hotkey {
        hotkeys[action] ?? Self.defaultHotkeys[action]!
    }

    func setHotkey(_ hotkey: Hotkey, for action: HotkeyAction) {
        hotkeys[action] = hotkey
        defaults.set(
            [Int(hotkey.keyCode), Int(hotkey.carbonModifiers)],
            forKey: "hotkey.\(action.rawValue)"
        )
        NotificationCenter.default.post(name: .snipostHotkeysChanged, object: nil)
    }
}
