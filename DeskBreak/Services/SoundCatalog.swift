import AVFoundation
import Foundation
import UserNotifications

/// A selectable alert tone.
///
/// iOS gives no API for reading the system ringtone library, so notification
/// sounds must be files inside the app bundle: 30 seconds or less, and encoded
/// as .caf, .aiff or .wav (linear PCM). The bundled tones here are synthesised
/// 16-bit PCM .wav files — see `scripts/generate_sounds.py`.
struct AlertSound: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    /// `nil` means "no file": either the system default or silence, per `isSilent`.
    let fileName: String?
    let isSilent: Bool

    var notificationSound: UNNotificationSound? {
        if isSilent { return nil }
        guard let fileName else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(fileName))
    }
}

enum SoundCatalog {
    static let all: [AlertSound] = [
        AlertSound(id: "chime", name: "Chime",
                   detail: "Two-note descending bell", fileName: "chime.wav", isSilent: false),
        AlertSound(id: "marimba", name: "Marimba",
                   detail: "Three quick wooden notes", fileName: "marimba.wav", isSilent: false),
        AlertSound(id: "drop", name: "Water Drop",
                   detail: "Short falling blip", fileName: "drop.wav", isSilent: false),
        AlertSound(id: "bell", name: "Bell",
                   detail: "Struck bell with a long tail", fileName: "bell.wav", isSilent: false),
        AlertSound(id: "bowl", name: "Singing Bowl",
                   detail: "Soft, slow to fade", fileName: "bowl.wav", isSilent: false),
        AlertSound(id: "ping", name: "Ping",
                   detail: "Single high note", fileName: "ping.wav", isSilent: false),
        AlertSound(id: "system", name: "System Default",
                   detail: "Standard iOS notification tone", fileName: nil, isSilent: false),
        AlertSound(id: "silent", name: "Silent",
                   detail: "Banner and vibration only", fileName: nil, isSilent: true)
    ]

    static func sound(withID id: String) -> AlertSound {
        all.first { $0.id == id } ?? all[0]
    }

    static func notificationSound(forID id: String) -> UNNotificationSound? {
        sound(withID: id).notificationSound
    }
}

/// Plays a bundled tone so you can tell them apart while choosing.
/// Uses the ambient session category deliberately: previews respect the ring/silent
/// switch exactly the way the real notification will.
@MainActor
final class SoundPreviewPlayer {
    static let shared = SoundPreviewPlayer()

    private var player: AVAudioPlayer?

    func play(_ sound: AlertSound) {
        player?.stop()
        guard let fileName = sound.fileName else { return }
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
