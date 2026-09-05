import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted after a notification action is handled so the UI can refresh counts
    /// the next time it is on screen.
    static let deskBreakCountsChanged = Notification.Name("deskbreak.countsChanged")
}

/// Handles the Done / Snooze buttons on the alert itself, so a reminder can be
/// dealt with from the Lock Screen without unlocking into the app.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// Show the alert even when the app happens to be open and in front.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let rawKind = response.notification.request.content.userInfo["kind"] as? String
        guard let rawKind, let kind = ReminderKind(rawValue: rawKind) else { return }

        switch response.actionIdentifier {
        case NotificationScheduler.Action.done:
            DailyCounts.increment(kind)
            NotificationCenter.default.post(name: .deskBreakCountsChanged, object: nil)
        case NotificationScheduler.Action.snooze:
            let settings = ReminderSettings.load()
            await NotificationScheduler.shared.scheduleSnooze(for: kind, settings: settings)
        default:
            break
        }
    }
}
