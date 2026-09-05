import Foundation
import SwiftUI
import UserNotifications

/// Single source of truth for the views: the running session, the settings, and
/// the notification permission state.
@MainActor
final class SessionController: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var pendingNotificationCount = 0
    @Published private(set) var counts: [ReminderKind: Int] = [:]

    /// Any settings change reschedules the batch immediately, so an interval you
    /// change mid-session takes effect from the next reminder rather than the
    /// next session.
    @Published var settings: ReminderSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            Task { await rescheduleIfRunning() }
        }
    }

    private let scheduler = NotificationScheduler.shared

    init() {
        self.settings = ReminderSettings.load()
        self.session = Session.load()
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        scheduler.registerCategories()
        refreshCounts()
    }

    var isRunning: Bool { session != nil }

    // MARK: - Session control

    func start() async {
        if authorizationStatus == .notDetermined {
            authorizationStatus = await scheduler.requestAuthorization()
        }
        let new = Session(startingAt: Date(), lengthHours: settings.sessionLengthHours)
        new.save()
        session = new
        await scheduler.reschedule(session: new, settings: settings)
        await refreshPendingCount()
    }

    func pause() async {
        guard var current = session, !current.isPaused else { return }
        current.pause(at: Date())
        current.save()
        session = current
        await scheduler.cancelBatch()
        await refreshPendingCount()
    }

    func resume() async {
        guard var current = session, current.isPaused else { return }
        current.resume(at: Date())
        current.save()
        session = current
        await scheduler.reschedule(session: current, settings: settings)
        await refreshPendingCount()
    }

    func stop() async {
        session = nil
        Session.clear()
        scheduler.cancelEverything()
        await refreshPendingCount()
    }

    /// Called whenever the app comes back to the foreground: expires a finished
    /// session and tops the notification queue back up.
    func refreshOnForeground() async {
        authorizationStatus = await scheduler.authorizationStatus()
        refreshCounts()

        if let current = session, current.isFinished(now: Date()) {
            await stop()
            return
        }
        await rescheduleIfRunning()
        await refreshPendingCount()
    }

    func refreshCounts() {
        var updated: [ReminderKind: Int] = [:]
        for kind in ReminderKind.allCases {
            updated[kind] = DailyCounts.count(for: kind)
        }
        counts = updated
    }

    func count(for kind: ReminderKind) -> Int { counts[kind] ?? 0 }

    private func rescheduleIfRunning() async {
        guard let current = session, !current.isPaused else { return }
        await scheduler.reschedule(session: current, settings: settings)
    }

    private func refreshPendingCount() async {
        pendingNotificationCount = await scheduler.pendingCount()
    }
}
