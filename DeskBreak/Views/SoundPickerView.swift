import SwiftUI

struct SoundPickerView: View {
    let kind: ReminderKind

    @EnvironmentObject private var controller: SessionController
    private let player = SoundPreviewPlayer.shared

    private var selectedID: String { controller.settings.soundID(for: kind) }

    var body: some View {
        List {
            Section {
                ForEach(SoundCatalog.all) { sound in
                    Button {
                        controller.settings.setSoundID(sound.id, for: kind)
                        player.play(sound)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sound.name)
                                    .foregroundStyle(.primary)
                                Text(sound.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if sound.id == selectedID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } footer: {
                Text("Tap a tone to select and preview it. Previews respect the ring/silent switch, exactly as the real reminder will.")
            }
        }
        .navigationTitle("\(kind.displayName) sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
    }
}

#Preview {
    NavigationStack {
        SoundPickerView(kind: .water).environmentObject(SessionController())
    }
}
