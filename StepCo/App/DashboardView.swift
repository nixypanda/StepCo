import SwiftUI

struct DashboardView: View {
    @ObservedObject var repository: StepRepository

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                TodaySummaryCard(summary: repository.today, lastUpdated: repository.lastUpdated)

                if !recentDays.isEmpty {
                    RecentDaysSection(days: recentDays)
                }

                if let errorMessage = repository.errorMessage {
                    ContentUnavailableView("Health data unavailable", systemImage: "heart.text.square", description: Text(errorMessage))
                }
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
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

    private var recentDays: [DayStepSummary] {
        Array(repository.days.sorted { $0.date < $1.date }.suffix(7))
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

private struct RecentDaysSection: View {
    let days: [DayStepSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent days")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 16) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(days) { day in
                        RecentDayItem(day: day, maximumSteps: maximumSteps)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                WeeklyTargetSummary(
                    target: weeklyGoal,
                    percent: weeklyPercent,
                    level: weeklyLevel
                )
            }
        }
        .padding()
        .background(weeklyLevel.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var maximumSteps: Int {
        days.map(\.steps).max() ?? 0
    }

    private var weeklySteps: Int {
        days.reduce(0) { $0 + $1.steps }
    }

    private var weeklyGoal: Int {
        days.reduce(0) { $0 + $1.goal }
    }

    private var weeklyPercent: Int {
        guard weeklyGoal > 0 else { return 0 }
        return Int((Double(weeklySteps) / Double(weeklyGoal) * 100).rounded())
    }

    private var weeklyLevel: StepGoalLevel {
        guard weeklyGoal > 0 else { return .low }

        if weeklySteps >= weeklyGoal {
            return .met
        }

        if weeklySteps >= weeklyGoal / 2 {
            return .warning
        }

        return .low
    }
}

private struct WeeklyTargetSummary: View {
    let target: Int
    let percent: Int
    let level: StepGoalLevel

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("\(percent)%")
                .font(.title3.weight(.bold))
                .foregroundStyle(level.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Target \(target.stepText)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 72, alignment: .trailing)
        .padding(.bottom, 22)
    }
}

private struct RecentDayItem: View {
    let day: DayStepSummary
    let maximumSteps: Int

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                VStack {
                    Spacer(minLength: 0)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(day.level.color)
                        .frame(width: 24, height: barHeight(in: proxy.size.height))
                        .overlay(alignment: .top) {
                            Text(day.shortStepsText)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .padding(.horizontal, 2)
                                .padding(.top, 6)
                        }
                }
            }

            Text(StepFormatters.weekdaySymbol.string(from: day.date))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity)
    }

    private func barHeight(in availableHeight: CGFloat) -> CGFloat {
        guard maximumSteps > 0 else { return 32 }

        let ratio = Double(day.steps) / Double(maximumSteps)
        return max(32, availableHeight * min(max(ratio, 0), 1))
    }
}
