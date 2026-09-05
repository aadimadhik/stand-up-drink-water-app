import Foundation

/// The two things this app nags you about. Everything that differs between them
/// (copy, icon, notification category, settings keys) lives here.
enum ReminderKind: String, CaseIterable, Identifiable, Codable {
    case water
    case stand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water: return "Water"
        case .stand: return "Stand up"
        }
    }

    var symbolName: String {
        switch self {
        case .water: return "drop.fill"
        case .stand: return "figure.walk"
        }
    }

    var notificationTitle: String {
        switch self {
        case .water: return "Time to drink water"
        case .stand: return "Time to stand up"
        }
    }

    var categoryIdentifier: String { "deskbreak.\(rawValue)" }

    /// Notification identifiers are namespaced per kind so a reschedule can wipe
    /// the batch without touching pending snoozes.
    var requestPrefix: String { "batch.\(rawValue)." }

    func notificationBody(occurrence: Int, elapsed: TimeInterval) -> String {
        let elapsedText = Self.elapsedFormatter.string(from: elapsed) ?? "0m"
        switch self {
        case .water:
            return "Glass #\(occurrence) · \(elapsedText) at the desk"
        case .stand:
            return "Break #\(occurrence) · stretch for a minute"
        }
    }

    var doneActionTitle: String {
        switch self {
        case .water: return "Drank it"
        case .stand: return "Stood up"
        }
    }

    private static let elapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()
}
