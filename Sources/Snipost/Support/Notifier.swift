import AppKit
import UserNotifications

/// System notifications (Notification Center). Falls back to the in-app toast
/// during `swift run` dev sessions, where no app bundle exists and the
/// UserNotifications framework would refuse to work.
@MainActor
enum Notifier {
    private static var requested = false

    private static var canUseSystemNotifications: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static func requestPermissionIfNeeded() {
        guard canUseSystemNotifications, !requested else { return }
        requested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(title: String, body: String) {
        guard canUseSystemNotifications else {
            Toast.show(title)
            return
        }
        requestPermissionIfNeeded()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
