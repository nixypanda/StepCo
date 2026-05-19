import XCTest

@testable import StepCo

final class StepSummaryModelsTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 1
    return calendar
  }

  func testRecentDaysSummaryKeepsLatestSevenDaysInAscendingOrder() throws {
    let days = try (1...9).reversed().map { day in
      try makeSummary(year: 2026, month: 1, day: day, steps: day * 1_000, goal: 10_000)
    }

    let summary = RecentDaysSummary(days: days)

    XCTAssertEqual(
      summary.days.map { calendar.component(.day, from: $0.date) },
      [3, 4, 5, 6, 7, 8, 9])
    XCTAssertEqual(summary.maximumSteps, 9_000)
  }

  func testRecentDaysSummaryComputesTotalsPercentAndLevel() throws {
    let summary = RecentDaysSummary(days: [
      try makeSummary(year: 2026, month: 1, day: 1, steps: 5_000, goal: 10_000),
      try makeSummary(year: 2026, month: 1, day: 2, steps: 8_000, goal: 10_000),
    ])

    XCTAssertEqual(summary.totalSteps, 13_000)
    XCTAssertEqual(summary.totalGoal, 20_000)
    XCTAssertEqual(summary.percent, 65)
    XCTAssertEqual(summary.level, .warning)
  }

  func testEmptyRecentDaysSummaryUsesZeroTotalsAndLowLevel() {
    let summary = RecentDaysSummary(days: [])

    XCTAssertTrue(summary.days.isEmpty)
    XCTAssertEqual(summary.maximumSteps, 0)
    XCTAssertEqual(summary.totalSteps, 0)
    XCTAssertEqual(summary.totalGoal, 0)
    XCTAssertEqual(summary.percent, 0)
    XCTAssertEqual(summary.level, .low)
  }

  func testMonthlySummariesGroupByMonthAndSortNewestFirst() throws {
    let summaries = MonthlyStepSummary.summaries(
      from: [
        try makeSummary(year: 2026, month: 1, day: 2, steps: 2_000, goal: 5_000),
        try makeSummary(year: 2026, month: 2, day: 1, steps: 3_000, goal: 5_000),
        try makeSummary(year: 2026, month: 1, day: 1, steps: 1_000, goal: 5_000),
      ],
      calendar: calendar
    )

    XCTAssertEqual(summaries.map { calendar.component(.month, from: $0.month) }, [2, 1])
    XCTAssertEqual(summaries[1].days.map { calendar.component(.day, from: $0.date) }, [1, 2])
    XCTAssertEqual(summaries[1].totalSteps, 3_000)
    XCTAssertEqual(summaries[1].totalGoal, 10_000)
    XCTAssertEqual(summaries[1].level, .low)
  }

  func testMonthlySummaryComputesMetLevel() throws {
    let summary = MonthlyStepSummary(
      month: try makeDate(year: 2026, month: 1, day: 1),
      days: [
        try makeSummary(year: 2026, month: 1, day: 1, steps: 5_000, goal: 5_000),
        try makeSummary(year: 2026, month: 1, day: 2, steps: 6_000, goal: 5_000),
      ],
      calendar: calendar
    )

    XCTAssertEqual(summary.totalSteps, 11_000)
    XCTAssertEqual(summary.totalGoal, 10_000)
    XCTAssertEqual(summary.level, .met)
  }

  func testMonthlySummaryLeadingBlanksRespectCalendarFirstWeekday() throws {
    var mondayFirstCalendar = calendar
    mondayFirstCalendar.firstWeekday = 2

    let summary = MonthlyStepSummary(
      month: try makeDate(year: 2026, month: 1, day: 1),
      days: [
        try makeSummary(year: 2026, month: 1, day: 1, steps: 1_000, goal: 5_000)
      ],
      calendar: mondayFirstCalendar
    )

    XCTAssertEqual(summary.leadingBlankCount, 3)
    XCTAssertEqual(
      summary.weekdaySymbols.first, mondayFirstCalendar.veryShortStandaloneWeekdaySymbols[1])
  }

  private func makeSummary(
    year: Int,
    month: Int,
    day: Int,
    steps: Int,
    goal: Int
  ) throws -> DayStepSummary {
    DayStepSummary(
      date: try makeDate(year: year, month: month, day: day),
      steps: steps,
      distanceKilometers: 0,
      goal: goal
    )
  }

  private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
    try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day)))
  }
}
