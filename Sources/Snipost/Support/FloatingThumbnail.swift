import AppKit
import SwiftUI

/// The 3-second flow: after a capture, a small panel slides into the bottom-right
/// corner with the beautified result and one-click actions. Auto-dismisses
/// unless the mouse is over it.
@MainActor
enum FloatingThumbnail {
    private static var panel: NSPanel?
    private static var hovering = false

    struct Actions {
        var onEdit: () -> Void
        var onCopy: () -> Void
        var onSave: () -> Void
        var onDrive: () -> Void
    }

    static func show(rendered: CGImage, actions: Actions) {
        hide(animated: false)

        let image = NSImage(cgImage: rendered, size: NSSize(width: rendered.width, height: rendered.height))
        let view = ThumbnailView(
            image: image,
            onEdit: { hide(); actions.onEdit() },
            onCopy: { actions.onCopy(); hide() },
            onSave: { actions.onSave(); hide() },
            onDrive: { actions.onDrive() },
            onClose: { hide() },
            onHover: { hovering = $0 }
        )

        let hosting = NSHostingController(rootView: view)
        let size = hosting.view.fittingSize
        let newPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.level = .floating
        newPanel.hasShadow = true
        newPanel.isReleasedWhenClosed = false
        newPanel.contentViewController = hosting

        var finalOrigin = NSPoint.zero
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            finalOrigin = NSPoint(
                x: visible.maxX - size.width - 20,
                y: visible.minY + 20
            )
        }

        // Enter: slide up + fade — softer than popping into place.
        newPanel.setFrameOrigin(NSPoint(x: finalOrigin.x, y: finalOrigin.y - 14))
        newPanel.alphaValue = 0
        newPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.24
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newPanel.animator().alphaValue = 1
            newPanel.animator().setFrameOrigin(finalOrigin)
        }

        panel = newPanel
        hovering = false
        scheduleDismiss(for: newPanel, after: 8)
    }

    static func hide(animated: Bool = true) {
        guard let dismissing = panel else { return }
        panel = nil
        guard animated else {
            dismissing.orderOut(nil)
            return
        }
        // Exit: subtler than the entrance.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            dismissing.animator().alphaValue = 0
        }, completionHandler: {
            dismissing.orderOut(nil)
        })
    }

    private static func scheduleDismiss(for target: NSPanel, after seconds: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            guard panel === target else { return }
            if hovering {
                scheduleDismiss(for: target, after: 3) // check again later
            } else {
                hide()
            }
        }
    }
}

private struct ThumbnailView: View {
    let image: NSImage
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    let onDrive: () -> Void
    let onClose: () -> Void
    let onHover: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 240, maxHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.1)
                                    : Color.black.opacity(0.1),
                                lineWidth: 1
                            )
                    )
                    .onTapGesture(perform: onEdit)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(5)
            }

            HStack(spacing: 6) {
                thumbButton("pencil", "Edit", action: onEdit)
                thumbButton("doc.on.doc", "Copy", action: onCopy)
                thumbButton("square.and.arrow.down", "Save", action: onSave)
                thumbButton("icloud.and.arrow.up", "Drive", action: onDrive)
            }
        }
        .padding(10)
        .background(
            // Outer 16 = inner 6 + 10 padding: concentric corners.
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.1))
        )
        .padding(6)
        .onHover(perform: onHover)
    }

    private func thumbButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 42, height: 28)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.07)))
                .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(ThumbPressStyle())
        .help(help)
    }
}

private struct ThumbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
