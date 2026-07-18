import AppKit
import SwiftUI

struct HistoryView: View {
    let onOpen: (URL) -> Void

    @State private var items: [URL] = []
    @State private var thumbnails: [URL: NSImage] = [:]

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No captures yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(items, id: \.self) { url in
                            thumbnailCell(url)
                        }
                    }
                    .padding(12)
                }
            }

            Divider()
            HStack {
                Text("\(items.count) captures")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear All") {
                    HistoryStore.clear()
                    reload()
                }
                .disabled(items.isEmpty)
            }
            .padding(10)
        }
        .frame(width: 640, height: 460)
        .onAppear(perform: reload)
    }

    private func thumbnailCell(_ url: URL) -> some View {
        Group {
            if let thumb = thumbnails[url] {
                Image(nsImage: thumb).resizable().scaledToFill()
            } else {
                Color.primary.opacity(0.06)
            }
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.1)))
        .contentShape(Rectangle())
        .onTapGesture { onOpen(url) }
        .contextMenu {
            Button("Open in Editor") { onOpen(url) }
            Button("Delete", role: .destructive) {
                HistoryStore.delete(url)
                reload()
            }
        }
        .task {
            guard thumbnails[url] == nil else { return }
            let cg = await Task.detached(priority: .utility) {
                WallpaperLibrary.thumbnail(for: url, maxPixel: 320)
            }.value
            if let cg {
                thumbnails[url] = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            }
        }
    }

    private func reload() {
        items = HistoryStore.list()
    }
}

@MainActor
final class HistoryWindowController: NSWindowController {
    static var shared: HistoryWindowController?

    static func show(onOpen: @escaping (URL) -> Void) {
        let controller: HistoryWindowController
        if let existing = shared {
            controller = existing
            controller.window?.contentViewController = NSHostingController(rootView: HistoryView(onOpen: onOpen))
        } else {
            let hosting = NSHostingController(rootView: HistoryView(onOpen: onOpen))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Snipost History"
            window.styleMask = [.titled, .closable, .resizable]
            window.isReleasedWhenClosed = false
            controller = HistoryWindowController(window: window)
            shared = controller
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}
