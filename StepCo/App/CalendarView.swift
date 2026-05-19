import SwiftUI

struct CalendarView: View {
  let days: [DayStepSummary]
  let loadMoreHistory: () async -> Void
  private let calendar = Calendar.current

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 28) {
          ForEach(months, id: \.month) { month in
            MonthSection(summary: month)
              .task(id: month.month) {
                guard month.month == months.last?.month else { return }
                await loadMoreHistory()
              }
          }
        }
        .padding()
      }
      .navigationTitle("Calendar")
    }
  }

  private var months: [MonthlyStepSummary] {
    MonthlyStepSummary.summaries(from: days, calendar: calendar)
  }
}

private struct MonthSection: View {
  let summary: MonthlyStepSummary

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(StepFormatters.monthTitle.string(from: summary.month))
          .font(.headline)
        Spacer()
        Text("\(summary.totalSteps.stepText) steps")
          .foregroundStyle(.secondary)
      }

      LazyVGrid(columns: columns, spacing: 14) {
        ForEach(summary.weekdaySymbols.indices, id: \.self) { index in
          Text(summary.weekdaySymbols[index])
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }

        ForEach(0..<summary.leadingBlankCount, id: \.self) { _ in
          Color.clear
            .frame(height: 42)
        }

        ForEach(summary.days) { day in
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
    .background(summary.level.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}
