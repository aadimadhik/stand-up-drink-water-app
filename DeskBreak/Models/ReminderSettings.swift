import Foundation

/// User preferences. Small and flat enough that UserDefaults is the right store —
/// there is no model graph here to justify SwiftData.
struct ReminderSettings: Codable, Equatable {
    var waterIntervalMinutes: Int = 45
    var standIntervalMinutes: Int = 50
    var waterSoundID: String = "chime"
    var standSoundID: String = "marimba"
    var sessionLengthHours: Int = 8
    /// Follows each reminder with two more a minute apart, for when one alert
    /// slides past unnoticed. Costs 3x the notification budget.
    var persistentNudge: Bool = false

    static let intervalChoices = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 75, 90, 120]
    static let sessionLengthChoices = [2, 4, 6, 8, 10, 12]

    func intervalMinutes(for kind: ReminderKind) -> Int {
        switch kind {
        case .water: return waterIntervalMinutes
        case .stand: return standIntervalMinutes
        }
    }

    func intervalSeconds(for kind: ReminderKind) -> TimeInterval {
        TimeInterval(intervalMinutes(for: kind) * 60)
    }

    func soundID(for kind: ReminderKind) -> String {
        switch kind {
        case .water: return waterSoundID
        case .stand: return standSoundID
        }
    }

    mutating func setSoundID(_ id: String, for kind: ReminderKind) {
        switch kind {
        case .water: waterSoundID = id
        case .stand: standSoundID = id
        }
    }

    // MARK: - Persistence

    private static let defaultsKey = "deskbreak.settings"

    static func load(from defaults: UserDefaults = .standard) -> ReminderSettings {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(ReminderSettings.self, from: data) else {
            return ReminderSettings()
        }
        return decoded
    }

    func save(to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
