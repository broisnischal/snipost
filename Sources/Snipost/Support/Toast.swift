import AppKit

/// Small transient pill of text near the bottom of the screen — feedback for
/// instant-mode captures ("Copied to clipboard") without stealing focus.
@MainActor
enum Toast {
    private static var panel: NSPanel?

    static func show(_ text: String) {
        panel?.orderOut(nil)

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.sizeToFit()

        let padding: CGFloat = 14
        let container = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: label.frame.width + padding * 2,
            height: label.frame.height + 16
        ))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        container.layer?.cornerRadius = container.frame.height / 2
        label.setFrameOrigin(NSPoint(x: padding, y: 8))
        container.addSubview(label)

        let newPanel = NSPanel(
            contentRect: container.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.level = .statusBar
        newPanel.ignoresMouseEvents = true
        newPanel.hasShadow = true
        newPanel.isReleasedWhenClosed = false
        newPanel.contentView = container

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            newPanel.setFrameOrigin(NSPoint(
                x: visible.midX - container.frame.width / 2,
                y: visible.minY + 100
            ))
        }
        newPanel.alphaValue = 1
        newPanel.orderFrontRegardless()
        panel = newPanel

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard Toast.panel === newPanel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                newPanel.animator().alphaValue = 0
            }, completionHandler: {
                newPanel.orderOut(nil)
                if Toast.panel === newPanel { Toast.panel = nil }
            })
        }
    }
}
