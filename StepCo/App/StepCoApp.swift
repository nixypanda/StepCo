import SwiftUI

@main
struct StepCoApp: App {
    @StateObject private var settings: StepSettingsStore
    @StateObject private var settingsSync: StepSettingsSync

    init() {
        let settings = StepSettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _settingsSync = StateObject(wrappedValue: StepSettingsSync(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
    }
}
