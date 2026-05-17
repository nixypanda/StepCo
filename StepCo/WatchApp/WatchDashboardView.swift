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

        VStack(spacing: 10) {
            Text(summary.distanceKilometers.kilometerText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(summary.steps.stepText)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Gauge(value: summary.progress) {
                Text("Steps")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .stepTint(summary.level)
            .scaleEffect(1.25)
            .padding(.top, 8)
        }
        .containerBackground(summary.level.color.opacity(0.18), for: .navigation)
        .task {
            await repository.refresh()
        }
    }
}
