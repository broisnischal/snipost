import AppKit
import ApplicationServices
import ScreenCaptureKit
import SwiftUI

extension CaptureService {
    /// Scrolling capture: select an area, then Snipost drives the page —
    /// synthetic scroll events between frames, stitched by row matching.
    /// Needs Accessibility permission (to post scroll events).
    @MainActor
    static func captureScrolling(completion: @escaping @MainActor (CGImage?) -> Void) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            presentAccessibilityHelp()
            completion(nil)
            return
        }

        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let target = targetDisplay(in: content) else {
                    completion(nil)
                    return
                }
                try await Task.sleep(nanoseconds: 200_000_000) // let menus close
                let frozen = try await captureDisplay(target.display, showsCursor: false)
                let viewSize = target.screen.frame.size
                SelectionOverlayController.begin(
                    mode: .area,
                    screen: target.screen,
                    frozen: frozen,
                    windows: []
                ) { result in
                    if case .rect(let viewRect) = result {
                        let session = ScrollingCaptureSession(
                            display: target.display,
                            screen: target.screen,
                            viewRect: viewRect,
                            viewSize: viewSize,
                            completion: completion
                        )
                        session.start()
                    } else {
                        completion(nil)
                    }
                }
            } catch {
                completion(nil)
            }
        }
    }

    @MainActor
    private static func presentAccessibilityHelp() {
        let alert = NSAlert()
        alert.messageText = "Snipost needs Accessibility permission to auto-scroll"
        alert.informativeText = """
        Enable Snipost in System Settings → Privacy & Security → Accessibility, \
        then run the scrolling capture again. If scrolling still doesn't move \
        after granting, quit and reopen Snipost once. (You can also scroll the \
        page yourself during a capture — Snipost stitches whatever moves.)
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

@MainActor
final class ScrollingCaptureSession: ObservableObject {
    private static var current: ScrollingCaptureSession?

    @Published var frameCount = 1
    @Published var totalHeight = 0

    private let display: SCDisplay
    private let screen: NSScreen
    private let viewRect: CGRect
    private let viewSize: CGSize
    private let completion: @MainActor (CGImage?) -> Void
    private var stopRequested = false
    private var hud: NSPanel?

    init(
        display: SCDisplay,
        screen: NSScreen,
        viewRect: CGRect,
        viewSize: CGSize,
        completion: @escaping @MainActor (CGImage?) -> Void
    ) {
        self.display = display
        self.screen = screen
        self.viewRect = viewRect
        self.viewSize = viewSize
        self.completion = completion
    }

    func start() {
        Self.current?.stopRequested = true
        Self.current = self
        showHUD()
        Task { @MainActor in
            await run()
        }
    }

    func requestStop() {
        stopRequested = true
    }

    private func run() async {
        defer {
            hud?.orderOut(nil)
            hud = nil
            if Self.current === self { Self.current = nil }
        }

        let location = scrollLocation()
        CGWarpMouseCursorPosition(location)
        try? await Task.sleep(nanoseconds: 200_000_000) // overlay gone, cursor settled

        guard var previous = await captureRegion() else {
            completion(nil)
            return
        }
        var segments: [CGImage] = [previous]
        totalHeight = previous.height

        let scrollPoints = Int32(max(60, viewRect.height * 0.55))
        var stalls = 0

        for _ in 0..<60 {
            if stopRequested { break }
            postScroll(points: scrollPoints, at: location)
            try? await Task.sleep(nanoseconds: 450_000_000) // let content settle
            guard let frame = await captureRegion() else { break }

            let prev = previous
            let fresh = await Task.detached(priority: .userInitiated) {
                Stitcher.newRowsCount(previous: prev, next: frame)
            }.value

            if fresh < 8 {
                // Patience: this also covers users scrolling manually (e.g.
                // when synthetic events are blocked) at their own pace.
                stalls += 1
                if stalls >= 6 { break } // ~3s of no movement = the bottom
                continue
            }
            stalls = 0

            let sliceRect = CGRect(x: 0, y: frame.height - fresh, width: frame.width, height: fresh)
            guard let slice = frame.cropping(to: sliceRect) else { break }
            segments.append(slice)
            previous = frame
            frameCount += 1
            totalHeight += fresh
            if totalHeight > 24_000 { break } // sanity cap
        }

        let all = segments
        if all.count == 1 {
            // Synthetic scrolls produced no movement at all — tell the user
            // why instead of silently handing back a single frame.
            Toast.show("Page didn't scroll — check Accessibility for Snipost, or scroll manually during capture")
        }
        let stitched = await Task.detached(priority: .userInitiated) {
            Stitcher.stack(all)
        }.value
        completion(stitched)
    }

    private func captureRegion() async -> CGImage? {
        do {
            // Fresh content each frame so our HUD can be excluded from the shot.
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let liveDisplay = content.displays.first { $0.displayID == display.displayID } ?? display
            let mine = content.windows.filter {
                $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier
            }
            let filter = SCContentFilter(display: liveDisplay, excludingWindows: mine)
            let config = SCStreamConfiguration()
            let scale = CGFloat(filter.pointPixelScale)
            config.width = Int(filter.contentRect.width * scale)
            config.height = Int(filter.contentRect.height * scale)
            config.showsCursor = false
            config.captureResolution = .best
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return CaptureService.crop(image, viewRect: viewRect, viewSize: viewSize)
        } catch {
            return nil
        }
    }

    /// Center of the selection in CG global coordinates (top-left origin).
    private func scrollLocation() -> CGPoint {
        let cocoaX = screen.frame.minX + viewRect.midX
        let cocoaY = screen.frame.minY + viewRect.midY
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        return CGPoint(x: cocoaX, y: primaryHeight - cocoaY)
    }

    private func postScroll(points: Int32, at location: CGPoint) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: -points, // negative = scroll down (reveal content below)
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.location = location
        event.post(tap: .cghidEventTap)
    }

    private func showHUD() {
        let hosting = NSHostingController(rootView: ScrollingHUD(session: self))
        let size = hosting.view.fittingSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hosting

        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.maxY - size.height - 12
        ))
        panel.orderFrontRegardless()
        hud = panel
    }
}

private struct ScrollingHUD: View {
    @ObservedObject var session: ScrollingCaptureSession

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            VStack(alignment: .leading, spacing: 1) {
                Text("Scrolling capture — \(session.frameCount) frames · \(session.totalHeight) px")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                Text("You can also scroll the page yourself")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Button("Stop") { session.requestStop() }
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.1)))
        .padding(6)
    }
}

/// Frame stitching: fingerprint every row (FNV hash over sampled pixels in the
/// middle columns — skipping edges and the scrollbar), then find the scroll
/// offset where the frames' overlap agrees.
enum Stitcher {
    /// How many rows of new content entered at the bottom of `next` (0 = none).
    static func newRowsCount(previous: CGImage, next: CGImage) -> Int {
        guard previous.width == next.width,
              previous.height == next.height,
              let hp = rowHashes(previous),
              let hn = rowHashes(next)
        else { return 0 }
        if hp == hn { return 0 }

        let height = hp.count
        let minOverlap = max(40, height / 5)
        guard height > minOverlap + 8 else { return 0 }

        // Content moved up by s: next[i] == previous[i + s]. Smallest s that
        // makes the overlap agree wins (largest overlap = safest match).
        for s in 8...(height - minOverlap) {
            var matches = 0
            var total = 0
            var i = 0
            while i < height - s {
                total += 1
                if hn[i] == hp[i + s] { matches += 1 }
                i += 7
            }
            if total >= 10, Double(matches) / Double(total) >= 0.9 {
                return s
            }
        }
        return 0
    }

    static func stack(_ segments: [CGImage]) -> CGImage? {
        guard let first = segments.first else { return nil }
        guard segments.count > 1 else { return first }
        let width = first.width
        let totalHeight = segments.reduce(0) { $0 + $1.height }
        guard totalHeight > 0,
              let ctx = CGContext(
                data: nil, width: width, height: totalHeight,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return first }

        var yFromTop = 0
        for segment in segments {
            let rect = CGRect(
                x: 0,
                y: totalHeight - yFromTop - segment.height,
                width: width,
                height: segment.height
            )
            ctx.draw(segment, in: rect)
            yFromTop += segment.height
        }
        return ctx.makeImage()
    }

    private static func rowHashes(_ image: CGImage) -> [UInt64]? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Bitmap memory is top-down: buffer row 0 is the visual top row.
        // Sample the middle band of columns — skips window chrome on the left
        // and the overlay scrollbar on the right.
        let x0 = max(4, Int(Double(width) * 0.08))
        let x1 = min(width - 4, Int(Double(width) * 0.85))
        guard x1 > x0 + 16 else { return nil }

        var hashes = [UInt64](repeating: 0, count: height)
        for y in 0..<height {
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            var x = x0
            while x < x1 {
                let index = y * bytesPerRow + x * 4
                hash = (hash ^ UInt64(data[index])) &* 0x0000_0100_0000_01b3
                hash = (hash ^ UInt64(data[index + 1])) &* 0x0000_0100_0000_01b3
                hash = (hash ^ UInt64(data[index + 2])) &* 0x0000_0100_0000_01b3
                x += 4
            }
            hashes[y] = hash
        }
        return hashes
    }
}
