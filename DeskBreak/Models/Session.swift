import Foundation

/// A desk session. Deliberately has no ticking timer of its own: every reminder
/// moment is derived arithmetically from `startedAt`, so the struct stays correct
/// after the app is suspended, killed, or the phone is restarted.
///
/// Pausing shifts `startedAt` and `endsAt` forward by the paused duration on
/// resume, which keeps "45 minutes of actual desk time" honest without tracking
/// per-kind offsets.
struct Session: Codable, Equatable {
    var startedAt: Date
    var endsAt: Date
    var pausedAt: Date?

    init(startingAt start: Date, lengthHours: Int) {
        self.startedAt = start
        self.endsAt = start.addingTimeInterval(TimeInterval(lengthHours) * 3600)
        self.pausedAt = nil
    }

    var isPaused: Bool { pausedAt != nil }

    /// While paused, all countdowns freeze at the moment of pausing.
    func referenceDate(now: Date) -> Date { pausedAt ?? now }

    func isFinished(now: Date) -> Bool { referenceDate(now: now) >= endsAt }

    func elapsed(now: Date) -> TimeInterval {
        max(0, referenceDate(now: now).timeIntervalSince(startedAt))
    }

    func remainingInSession(now: Date) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(referenceDate(now: now)))
    }

    /// 1-based index of the reminder that is coming up next.
    func nextOccurrence(interval: TimeInterval, now: Date) -> Int {
        guard interval > 0 else { return 1 }
        return Int(floor(elapsed(now: now) / interval)) + 1
    }

    func fireDate(interval: TimeInterval, occurrence: Int) -> Date {
        startedAt.addingTimeInterval(TimeInterval(occurrence) * interval)
    }

    /// `nil` once the remaining reminders would fall past the end of the session.
    func nextFireDate(interval: TimeInterval, now: Date) -> Date? {
        guard interval > 0 else { return nil }
        let date = fireDate(interval: interval, occurrence: nextOccurrence(interval: interval, now: now))
        return date <= endsAt ? date : nil
    }

    func timeUntilNextFire(interval: TimeInterval, now: Date) -> TimeInterval? {
        guard let date = nextFireDate(interval: interval, now: now) else { return nil }
        return max(0, date.timeIntervalSince(referenceDate(now: now)))
    }

    mutating func pause(at date: Date) {
        guard pausedAt == nil else { return }
        pausedAt = date
    }

    mutating func resume(at date: Date) {
        guard let pausedAt else { return }
        let pausedFor = max(0, date.timeIntervalSince(pausedAt))
        startedAt = startedAt.addingTimeInterval(pausedFor)
        endsAt = endsAt.addingTimeInterval(pausedFor)
        self.pausedAt = nil
    }

    // MARK: - Persistence

    private static let defaultsKey = "deskbreak.session"

    static func load(from defaults: UserDefaults = .standard) -> Session? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
