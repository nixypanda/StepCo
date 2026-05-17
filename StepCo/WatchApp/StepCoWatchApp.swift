import SwiftUI

@main
struct StepCoWatchApp: App {
    @StateObject private var settings = StepSettingsStore()

    var body: some Scene {
        WindowGroup {
            WatchDashboardView(settings: settings)
        }
    }
}
