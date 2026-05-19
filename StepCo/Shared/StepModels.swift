import Foundation
import SwiftUI

enum StepGoalLevel: String, Codable, Equatable {
  case low
  case warning
  case met

  var color: Color {
    switch self {
    case .low:
      .red
    case .warning:
      .orange
    case .met:
      .green
    }
  }
}

struct DayStepSummary: Identifiable, Codable, Equatable {
  var id: Date { date }

  let date: Date
  let steps: Int
  let distanceKilometers: Double
  let goal: Int

  var progress: Double {
    guard goal > 0 else { return 0 }
    return min(Double(steps) / Double(goal), 1)
  }

  var level: StepGoalLevel {
    StepGoalLevel.level(steps: steps, goal: goal)
  }

  var shortStepsText: String {
    if steps >= 1_000 {
      return "\(steps / 1_000)k"
    }

    return "\(steps)"
  }
}

struct RecentDaysSummary: Equatable {
  let days: [DayStepSummary]

  init(days: [DayStepSummary]) {
    self.days = Array(days.sorted { $0.date < $1.date }.suffix(7))
  }

  var maximumSteps: Int {
    days.map(\.steps).max() ?? 0
  }

  var totalSteps: Int {
    days.reduce(0) { $0 + $1.steps }
  }

  var totalGoal: Int {
    days.reduce(0) { $0 + $1.goal }
  }

  var percent: Int {
    guard totalGoal > 0 else { return 0 }
    return Int((Double(totalSteps) / Double(totalGoal) * 100).rounded())
  }

  var level: StepGoalLevel {
    StepGoalLevel.level(steps: totalSteps, goal: totalGoal)
  }
}

struct MonthlyStepSummary: Equatable {
  let month: Date
  let days: [DayStepSummary]

  private let calendar: Calendar

  init(month: Date, days: [DayStepSummary], calendar: Calendar = .current) {
    self.month = month
    self.days = days.sorted { $0.date < $1.date }
    self.calendar = calendar
  }

  static func summaries(from days: [DayStepSummary], calendar: Calendar = .current)
    -> [MonthlyStepSummary]
  {
    let grouped = Dictionary(grouping: days) { day in
      let components = calendar.dateComponents([.year, .month], from: day.date)
      return calendar.date(from: components) ?? day.date
    }

    return
      grouped
      .map { MonthlyStepSummary(month: $0.key, days: $0.value, calendar: calendar) }
      .sorted { $0.month > $1.month }
  }

  var totalSteps: Int {
    days.reduce(0) { $0 + $1.steps }
  }

  var totalGoal: Int {
    days.reduce(0) { $0 + $1.goal }
  }

  var level: StepGoalLevel {
    StepGoalLevel.level(steps: totalSteps, goal: totalGoal)
  }

  var leadingBlankCount: Int {
    guard let first = days.first else { return 0 }
    let weekday = calendar.component(.weekday, from: first.date)
    return (weekday - calendar.firstWeekday + 7) % 7
  }

  var weekdaySymbols: [String] {
    let symbols = calendar.veryShortStandaloneWeekdaySymbols
    let start = calendar.firstWeekday - 1
    return Array(symbols[start...] + symbols[..<start])
  }
}

struct StepSettingsSnapshot: Codable, Equatable {
  let effectiveDate: Date
  let targetSteps: Int
}

struct CachedStepSnapshot: Codable, Equatable {
  let updatedAt: Date
  let today: DayStepSummary
}

enum StepFormatters {
  static let monthTitle: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM yyyy"
    return formatter
  }()

  static let dayNumber: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter
  }()

  static let weekdaySymbol: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEEE"
    return formatter
  }()

  static let integer: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter
  }()
}

extension Int {
  var stepText: String {
    StepFormatters.integer.string(from: NSNumber(value: self)) ?? "\(self)"
  }
}

extension Double {
  var kilometerText: String {
    String(format: "%.2f km", self)
  }
}

extension StepGoalLevel {
  fileprivate static func level(steps: Int, goal: Int) -> StepGoalLevel {
    guard goal > 0 else { return .low }

    if steps >= goal {
      return .met
    }

    if steps >= goal / 2 {
      return .warning
    }

    return .low
  }
}
