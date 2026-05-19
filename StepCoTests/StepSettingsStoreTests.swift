import XCTest

@testable import StepCo

final class StepSettingsStoreTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  private func makeStore() -> StepSettingsStore {
    let defaults = UserDefaults(suiteName: "com.nixypanda.StepCo.tests.\(UUID().uuidString)")!
    return StepSettingsStore(defaults: defaults, calendar: calendar)
  }

  func testDatesBeforeFirstSnapshotUseHistoricalDefaultTarget() throws {
    let store = makeStore()
    let first = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
    let beforeFirst = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2025, month: 12, day: 31)))

    store.replace(history: [
      StepSettingsSnapshot(effectiveDate: first, targetSteps: StepSettingsStore.defaultTargetSteps)
    ])

    XCTAssertEqual(store.settings(for: beforeFirst).targetSteps, 5_000)
    XCTAssertEqual(store.settings(for: first).targetSteps, StepSettingsStore.defaultTargetSteps)
  }

  func testMultipleChangesOnSameDayUseLatestTarget() throws {
    let store = makeStore()
    let day = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 9)))
    let laterSameDay = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 18)))

    store.replace(history: [
      StepSettingsSnapshot(effectiveDate: day, targetSteps: 5_000),
      StepSettingsSnapshot(effectiveDate: laterSameDay, targetSteps: 10_000),
    ])

    XCTAssertEqual(store.history.count, 1)
    XCTAssertEqual(store.settings(for: laterSameDay).targetSteps, 10_000)
  }

  func testDisplayHistoryIncludesPreInstallPeriodAndCurrentPeriod() throws {
    let store = makeStore()
    let first = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
    let second = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 3)))

    store.replace(history: [
      StepSettingsSnapshot(effectiveDate: first, targetSteps: StepSettingsStore.defaultTargetSteps),
      StepSettingsSnapshot(effectiveDate: second, targetSteps: 6_000),
    ])

    XCTAssertEqual(
      store.displayHistory.map(\.targetSteps),
      [
        5_000,
        StepSettingsStore.defaultTargetSteps,
        6_000,
      ])
    XCTAssertTrue(try XCTUnwrap(store.displayHistory.last).isCurrent)
  }
}
