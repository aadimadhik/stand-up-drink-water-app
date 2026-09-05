import Combine
import SwiftUI
import UIKit
import UserNotifications

struct HomeView: View {
    @EnvironmentObject private var controller: SessionController
    @State private var now = Date()
    @State private var showingSettings = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if controller.authorizationStatus == .denied {
                        permissionBanner
                    }

                    ForEach(ReminderKind.allCases) { kind in
                        CountdownCard(
                            kind: kind,
                            interval: controller.settings.intervalSeconds(for: kind),
                            session: controller.session,
                            now: now,
                            doneToday: controller.count(for: kind)
                        )
                    }

                    sessionSummary
                    controls
                    footnote
                }
                .padding()
            }
            .navigationTitle("DeskBreak")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(controller)
            }
        }
        .onReceive(tick) { date in
            now = date
            // The session can run out while the app sits open in the foreground.
            if let session = controller.session, session.isFinished(now: date) {
                Task { await controller.stop() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deskBreakCountsChanged)) { _ in
            controller.refreshCounts()
        }
    }

    // MARK: - Sections

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notifications are off", systemImage: "bell.slash.fill")
                .font(.headline)
            Text("DeskBreak delivers every reminder as a notification. Without permission it cannot remind you of anything.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open iPhone Settings", destination: url)
                    .font(.footnote.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private var sessionSummary: some View {
        HStack {
            if let session = controller.session {
                Label(
                    session.isPaused
                        ? "Paused"
                        : "\(Self.duration(session.elapsed(now: now))) at the desk",
                    systemImage: session.isPaused ? "pause.circle" : "clock"
                )
                Spacer()
                Text("\(Self.duration(session.remainingInSession(now: now))) left")
                    .foregroundStyle(.secondary)
            } else {
                Label("No session running", systemImage: "moon.zzz")
                Spacer()
                Text("\(controller.settings.sessionLengthHours) h when started")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var controls: some View {
        if let session = controller.session {
            HStack(spacing: 12) {
                Button {
                    Task {
                        if session.isPaused {
                            await controller.resume()
                        } else {
                            await controller.pause()
                        }
                    }
                } label: {
                    Label(session.isPaused ? "Resume" : "Pause",
                          systemImage: session.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    Task { await controller.stop() }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        } else {
            Button {
                Task { await controller.start() }
            } label: {
                Label("Start desk session", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var footnote: some View {
        Text(controller.isRunning
             ? "You can lock your phone now. Reminders are delivered by iOS, so they arrive even if DeskBreak is closed."
             : "Set your intervals in Settings, tap Start, then lock your phone.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// One reminder kind: a progress ring counting down to its next alert.
struct CountdownCard: View {
    let kind: ReminderKind
    let interval: TimeInterval
    let session: Session?
    let now: Date
    let doneToday: Int

    private var remaining: TimeInterval? {
        session?.timeUntilNextFire(interval: interval, now: now)
    }

    private var progress: Double {
        guard interval > 0, let remaining else { return 0 }
        return min(1, max(0, 1 - remaining / interval))
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: kind.symbolName)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(kind.displayName)
                    .font(.headline)
                Text(statusText)
                    .font(.system(.title3, design: .rounded).monospacedDigit())
                    .foregroundStyle(remaining == nil ? .secondary : .primary)
                Text("every \(Int(interval / 60)) min · \(doneToday) done today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var statusText: String {
        guard let session else { return "Not running" }
        guard let remaining else { return "No more this session" }
        if session.isPaused { return "Paused at \(HomeView.duration(remaining))" }
        return HomeView.duration(remaining)
    }

    private var tint: Color {
        switch kind {
        case .water: return .blue
        case .stand: return .green
        }
    }
}

#Preview {
    HomeView().environmentObject(SessionController())
}
