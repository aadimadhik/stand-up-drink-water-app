import Foundation

/// How many reminders you actually acted on today, incremented when you tap the
/// "Drank it" / "Stood up" button on the notification itself.
///
/// Kept as free functions over UserDefaults rather than an observable object
/// because the notification delegate writes to it from outside the view tree.
enum DailyCounts {
    private static func key(for kind: ReminderKind, on date: Date) -> String {
        "deskbreak.count.\(kind.rawValue).\(dayStamp(date))"
    }

    private static func dayStamp(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func count(for kind: ReminderKind,
                      on date: Date = Date(),
                      in defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: key(for: kind, on: date))
    }

    static func increment(_ kind: ReminderKind,
                          on date: Date = Date(),
                          in defaults: UserDefaults = .standard) {
        let key = key(for: kind, on: date)
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    static func reset(on date: Date = Date(), in defaults: UserDefaults = .standard) {
        for kind in ReminderKind.allCases {
            defaults.removeObject(forKey: key(for: kind, on: date))
        }
    }
}
