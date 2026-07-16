import AppKit
import SwiftUI

final class EditorWindowController: NSWindowController {
    convenience init(image: CGImage) {
        let model = EditorModel(source: image)
        let hosting = NSHostingController(rootView: EditorView(model: model))

        let window = NSWindow(contentViewController: hosting)
        window.title = "Snipost"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 980, height: 620))
        window.isReleasedWhenClosed = false
        window.center()

        self.init(window: window)
    }
}
