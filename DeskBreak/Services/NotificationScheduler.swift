import Foundation
import UserNotifications

/// Turns a `Session` into a batch of pending local notifications.
///
/// The app never runs a background timer — iOS suspends it seconds after the
/// screen locks. Instead every reminder for the session horizon is handed to
/// `UNUserNotificationCenter` up front and delivered by the system, which is why
/// the reminders still arrive after the app is force-quit.
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    enum Action {
        static let done = "deskbreak.action.done"
        static let snooze = "deskbreak.action.snooze"
    }

    static let snoozeInterval: TimeInterval = 5 * 60
    static let snoozePrefix = "snooze."

    /// iOS keeps at most 64 pending requests per app and silently drops the rest,
    /// so the batch is capped well under that and topped up whenever the app is
    /// foregrounded. With the persistent nudge on, each reminder costs 3 slots.
    private static let requestBudget = 52
    private static let nudgeRepeats = 2
    private static let nudgeSpacing: TimeInterval = 60

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission and categories

    func registerCategories() {
        let categories = ReminderKind.allCases.map { kind in
            UNNotificationCategory(
                identifier: kind.categoryIdentifier,
                actions: [
                    UNNotificationAction(identifier: Action.done,
                                         title: kind.doneActionTitle,
                                         options: []),
                    UNNotificationAction(identifier: Action.snooze,
                                         title: "Snooze 5 min",
                                         options: [])
                ],
                intentIdentifiers: [],
                options: []
            )
        }
        center.setNotificationCategories(Set(categories))
    }

    func requestAuthorization() async -> UNAuthorizationStatus {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return await authorizationStatus()
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }

    // MARK: - Scheduling

    /// Clears the existing batch and lays down a fresh one from `now`. Safe to call
    /// repeatedly — on start, on a settings change, and every time the app is
    /// foregrounded to top the queue back up.
    func reschedule(session: Session, settings: ReminderSettings) async {
        await cancelBatch()
        guard !session.isPaused else { return }

        let now = Date()
        guard !session.isFinished(now: now) else { return }

        let nudgesPerReminder = settings.persistentNudge ? Self.nudgeRepeats + 1 : 1
        let perKindBudget = Self.requestBudget / (ReminderKind.allCases.count * nudgesPerReminder)

        for kind in ReminderKind.allCases {
            let interval = settings.intervalSeconds(for: kind)
            guard interval >= 60 else { continue }
            let sound = SoundCatalog.notificationSound(forID: settings.soundID(for: kind))

            var occurrence = session.nextOccurrence(interval: interval, now: now)
            var scheduled = 0

            while scheduled < perKindBudget {
                let fire = session.fireDate(interval: interval, occurrence: occurrence)
                if fire > session.endsAt { break }

                let delay = fire.timeIntervalSince(now)
                // A trigger needs a positive interval; skip anything already past.
                guard delay > 0.5 else {
                    occurrence += 1
                    continue
                }

                let elapsed = fire.timeIntervalSince(session.startedAt)
                for nudge in 0..<nudgesPerReminder {
                    await add(
                        identifier: "\(kind.requestPrefix)\(occurrence).\(nudge)",
                        kind: kind,
                        body: kind.notificationBody(occurrence: occurrence, elapsed: elapsed),
                        sound: sound,
                        delay: delay + TimeInterval(nudge) * Self.nudgeSpacing
                    )
                }

                occurrence += 1
                scheduled += 1
            }
        }
    }

    func scheduleSnooze(for kind: ReminderKind, settings: ReminderSettings) async {
        await add(
            identifier: "\(Self.snoozePrefix)\(kind.rawValue).\(UUID().uuidString)",
            kind: kind,
            body: "Snoozed reminder — \(kind.displayName.lowercased()) now",
            sound: SoundCatalog.notificationSound(forID: settings.soundID(for: kind)),
            delay: Self.snoozeInterval
        )
    }

    /// Removes the scheduled batch but leaves pending snoozes alone, so a
    /// foreground top-up never swallows a snooze the user just asked for.
    func cancelBatch() async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { identifier in
                ReminderKind.allCases.contains { identifier.hasPrefix($0.requestPrefix) }
            }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelEverything() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func add(identifier: String,
                     kind: ReminderKind,
                     body: String,
                     sound: UNNotificationSound?,
                     delay: TimeInterval) async {
        let content = UNMutableNotificationContent()
        content.title = kind.notificationTitle
        content.body = body
        content.sound = sound
        content.categoryIdentifier = kind.categoryIdentifier
        // Groups the reminders per kind on the Lock Screen instead of stacking
        // one undifferentiated pile.
        content.threadIdentifier = kind.rawValue
        content.userInfo = ["kind": kind.rawValue]
        // Requesting .timeSensitive is free to set, but iOS only honours it when
        // the app carries the Time Sensitive Notifications capability — which a
        // free Personal Team cannot enable. Without it this degrades silently to
        // a normal notification; allow DeskBreak in your Focus instead.
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
