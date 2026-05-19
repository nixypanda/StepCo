import SwiftUI

struct WatchDashboardView: View {
  @ObservedObject var settings: StepSettingsStore
  @StateObject private var repository: StepRepository

  init(settings: StepSettingsStore) {
    self.settings = settings
    _repository = StateObject(wrappedValue: StepRepository(settings: settings))
  }

  var body: some View {
    let summary = repository.today

    ZStack {
      summary.level.color
        .opacity(0.16)
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: "figure.walk")
          .font(.title3)

        Text(summary.steps.stepText)
          .font(.system(.largeTitle, design: .rounded, weight: .bold))
          .minimumScaleFactor(0.65)
          .lineLimit(1)

        Text(summary.distanceKilometers.kilometerText)
          .font(.headline)

        ProgressView(value: summary.progress)
          .stepTint(summary.level)
      }
      .foregroundStyle(summary.level.color)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
    }
    .ignoresSafeArea()
    .task {
      await repository.startHealthUpdates()
    }
    .onChange(of: settings.history) { _, _ in
      Task {
        await repository.refresh()
      }
    }
  }
}
