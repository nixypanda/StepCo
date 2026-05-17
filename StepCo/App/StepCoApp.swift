import SwiftUI

@main
struct StepCoApp: App {
    @StateObject private var settings = StepSettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
    }
}
