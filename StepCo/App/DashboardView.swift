import SwiftUI

struct DashboardView: View {
    @ObservedObject var repository: StepRepository

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                TodaySummaryCard(summary: repository.today, lastUpdated: repository.lastUpdated)

                LabeledContent("Current streak") {
                    Text("\(repository.currentStreak) days")
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = repository.errorMessage {
                    ContentUnavailableView("Health data unavailable", systemImage: "heart.text.square", description: Text(errorMessage))
                }

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("StepCo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await repository.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(repository.isLoading)
                }
            }
        }
    }
}

private struct TodaySummaryCard: View {
    let summary: DayStepSummary
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "figure.walk")
                .font(.title)
                .foregroundStyle(summary.level.color)

            Text("\(summary.steps.stepText) steps")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))

            ProgressView(value: summary.progress) {
                Text("Daily target")
            } currentValueLabel: {
                Text("\(summary.goal.stepText) steps")
            }
            .stepTint(summary.level)
            .controlSize(.large)

            HStack {
                Label(summary.distanceKilometers.kilometerText, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                Spacer()
                if let lastUpdated {
                    Text(lastUpdated, style: .relative)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(summary.level.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
