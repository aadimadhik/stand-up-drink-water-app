import SwiftUI

@main
struct DeskBreakApp: App {
    @StateObject private var controller = SessionController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(controller)
        }
        .onChange(of: scenePhase) { _, phase in
            // Expire a finished session and top the notification queue back up
            // every time the app returns to the foreground.
            if phase == .active {
                Task { await controller.refreshOnForeground() }
            }
        }
    }
}
