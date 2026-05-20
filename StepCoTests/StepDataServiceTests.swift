import XCTest

@testable import StepCo

@MainActor
final class StepDataServiceTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  func testDemoStepDataServiceReturnsSummariesForRequestedRange() async throws {
    let service = DemoStepDataService(calendar: calendar)
    let start = try makeDate(year: 2026, month: 1, day: 1)
    let end = try makeDate(year: 2026, month: 1, day: 3)

    let summaries = try await service.summaries(from: start, through: end) { date in
      StepSettingsSnapshot(effectiveDate: date, targetSteps: 6_000)
    }

    XCTAssertEqual(summaries.map(\.date), [start, try makeDate(year: 2026, month: 1, day: 2), end])
    XCTAssertEqual(summaries.map(\.goal), [6_000, 6_000, 6_000])
    XCTAssertTrue(summaries.allSatisfy { $0.steps > 0 })
    XCTAssertTrue(summaries.allSatisfy { $0.distanceKilometers > 0 })
  }

  func testDemoStepDataServiceAuthorizationAndBackgroundDeliveryAreNoOps() async throws {
    let service = DemoStepDataService(calendar: calendar)
    var callbackWasCalled = false

    try await service.requestAuthorization()
    try await service.startBackgroundDelivery {
      callbackWasCalled = true
    }

    XCTAssertFalse(callbackWasCalled)
  }

  private func makeDate(year: Int, month: Int, day: Int) throws -> Date {
    try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day)))
  }
}
