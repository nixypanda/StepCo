import SwiftUI

struct CalendarView: View {
    let days: [DayStepSummary]
    let currentStreak: Int
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    LabeledContent("Current streak") {
                        Text("\(currentStreak) days")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(months, id: \.month) { month in
                        MonthSection(month: month.month, days: month.days)
                    }
                }
                .padding()
            }
            .navigationTitle("Calendar")
        }
    }

    private var months: [(month: Date, days: [DayStepSummary])] {
        let grouped = Dictionary(grouping: days) { day in
            let components = calendar.dateComponents([.year, .month], from: day.date)
            return calendar.date(from: components) ?? day.date
        }

        return grouped
            .map { ($0.key, $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.month > $1.month }
    }
}

private struct MonthSection: View {
    let month: Date
    let days: [DayStepSummary]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(StepFormatters.monthTitle.string(from: month))
                    .font(.headline)
                Spacer()
                Text("\(days.reduce(0) { $0 + $1.steps }.stepText) steps")
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<leadingBlankCount, id: \.self) { _ in
                    Color.clear
                        .frame(height: 42)
                }

                ForEach(days) { day in
                    VStack(spacing: 2) {
                        Text(day.shortStepsText)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(day.level.color)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)

                        Text(StepFormatters.dayNumber.string(from: day.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 42)
                }
            }
        }
        .padding()
        .background(monthlyLevel.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var leadingBlankCount: Int {
        guard let first = days.first else { return 0 }
        let weekday = calendar.component(.weekday, from: first.date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var monthlySteps: Int {
        days.reduce(0) { $0 + $1.steps }
    }

    private var monthlyGoal: Int {
        days.reduce(0) { $0 + $1.goal }
    }

    private var monthlyLevel: StepGoalLevel {
        guard monthlyGoal > 0 else { return .low }

        if monthlySteps >= monthlyGoal {
            return .met
        }

        if monthlySteps >= monthlyGoal / 2 {
            return .warning
        }

        return .low
    }
}
