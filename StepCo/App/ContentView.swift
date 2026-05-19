import SwiftUI

struct ContentView: View {
  @ObservedObject var settings: StepSettingsStore
  @StateObject private var repository: StepRepository

  init(settings: StepSettingsStore) {
    self.settings = settings
    _repository = StateObject(wrappedValue: StepRepository(settings: settings))
  }

  var body: some View {
    TabView {
      DashboardView(repository: repository)
        .tabItem {
          Label("Today", systemImage: "figure.walk")
        }

      CalendarView(days: repository.days) {
        await repository.loadMoreHistory()
      }
      .tabItem {
        Label("Calendar", systemImage: "calendar")
      }

      SettingsView(settings: settings) {
        Task {
          await repository.refresh()
        }
      }
      .tabItem {
        Label("Settings", systemImage: "gearshape")
      }
    }
    .task {
      await repository.startHealthUpdates()
    }
  }
}
