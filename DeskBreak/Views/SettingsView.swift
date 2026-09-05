import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var controller: SessionController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Intervals") {
                    Picker("Water every", selection: $controller.settings.waterIntervalMinutes) {
                        ForEach(ReminderSettings.intervalChoices, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    Picker("Stand up every", selection: $controller.settings.standIntervalMinutes) {
                        ForEach(ReminderSettings.intervalChoices, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                } footer: {
                    Text("Changes apply immediately, including to a session that is already running.")
                }

                Section("Sounds") {
                    ForEach(ReminderKind.allCases) { kind in
                        NavigationLink {
                            SoundPickerView(kind: kind)
                                .environmentObject(controller)
                        } label: {
                            HStack {
                                Label(kind.displayName, systemImage: kind.symbolName)
                                Spacer()
                                Text(SoundCatalog.sound(withID: controller.settings.soundID(for: kind)).name)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("iOS does not let apps use your iPhone's ringtones, so these are tones bundled with DeskBreak. Give water and standing different tones and you can tell them apart without looking.")
                }

                Section("Session") {
                    Picker("Session length", selection: $controller.settings.sessionLengthHours) {
                        ForEach(ReminderSettings.sessionLengthChoices, id: \.self) { hours in
                            Text("\(hours) hours").tag(hours)
                        }
                    }
                    Toggle("Persistent nudge", isOn: $controller.settings.persistentNudge)
                } footer: {
                    Text("A persistent nudge repeats each reminder twice more, a minute apart, for when one alert slides past unnoticed. It uses three times the notification budget, so fewer reminders are queued ahead.")
                }

                Section("If reminders don't arrive") {
                    Text("A Focus mode silences DeskBreak unless you allow it. Open Settings › Focus › your Focus › Apps and add DeskBreak.")
                    Text("The ring/silent switch also mutes notification sounds. On silent, you get vibration only.")
                    Text("This build is signed with a free Apple ID, so it stops launching seven days after you build it. Reconnect to your Mac and press Run again — your settings and counts survive.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Section {
                    LabeledContent("Queued reminders", value: "\(controller.pendingNotificationCount)")
                } footer: {
                    Text("iOS allows 64 pending notifications per app. DeskBreak stays under that and re-queues more each time you open it.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(SessionController())
}
