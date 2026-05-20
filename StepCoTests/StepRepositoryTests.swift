import XCTest

@testable import StepCo

@MainActor
final class StepRepositoryTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }

  func testRefreshLoadsSummariesFromInjectedDataService() async throws {
    let clock = MutableClock(try makeDate(year: 2026, month: 5, day: 20, hour: 12))
    let service = FakeStepDataService()
    let cache = StepSnapshotCacheSpy()
    let settings = makeSettings()
    let today = try makeSummary(year: 2026, month: 5, day: 20, steps: 4_200, goal: 7_500)
    service.summariesResult = [today]
    let repository = makeRepository(
      service: service, settings: settings, cache: cache, clock: clock)

    await repository.refresh()

    XCTAssertEqual(repository.days, [today])
    XCTAssertEqual(repository.lastUpdated, clock.current)
    XCTAssertFalse(repository.isLoading)
    XCTAssertNil(repository.errorMessage)
    XCTAssertEqual(service.authorizationRequestCount, 1)
  }

  func testRefreshUsesInjectedSettingsForGoals() async throws {
    let clock = MutableClock(try makeDate(year: 2026, month: 5, day: 20))
    let service = FakeStepDataService()
    let settings = makeSettings()
    let first = try makeDate(year: 2026, month: 5, day: 1)
    let second = try makeDate(year: 2026, month: 5, day: 10)
    settings.replace(history: [
      StepSettingsSnapshot(effectiveDate: first, targetSteps: 6_000),
      StepSettingsSnapshot(effectiveDate: second, targetSteps: 9_000),
    ])
    service.summariesHandler = { start, end, settingsForDate in
      _ = (start, end)
      return [
        DayStepSummary(
          date: first, steps: 1_000, distanceKilometers: 1, goal: settingsForDate(first).targetSteps
        ),
        DayStepSummary(
          date: second, steps: 2_000, distanceKilometers: 2,
          goal: settingsForDate(second).targetSteps),
      ]
    }
    let repository = makeRepository(service: service, settings: settings, clock: clock)

    await repository.refresh()

    XCTAssertEqual(repository.days.map(\.goal), [6_000, 9_000])
  }

  func testRefreshSavesTodaySnapshotToInjectedCacheAndForcesReload() async throws {
    let todayDate = try makeDate(year: 2026, month: 5, day: 20, hour: 12)
    let clock = MutableClock(todayDate)
    let service = FakeStepDataService()
    let cache = StepSnapshotCacheSpy()
    let today = DayStepSummary(date: todayDate, steps: 5_000, distanceKilometers: 3.75, goal: 7_500)
    service.summariesResult = [today]
    let repository = makeRepository(service: service, cache: cache, clock: clock)

    await repository.refresh()

    XCTAssertEqual(cache.savedSnapshots.map(\.today), [today])
    XCTAssertEqual(cache.reloadRequests, [true])
  }

  func testStartHealthUpdatesRefreshesThenStartsDataServiceUpdates() async throws {
    let clock = MutableClock(try makeDate(year: 2026, month: 5, day: 20))
    let service = FakeStepDataService()
    service.summariesResult = [
      try makeSummary(year: 2026, month: 5, day: 20, steps: 1_000, goal: 7_500)
    ]
    let repository = makeRepository(service: service, clock: clock)

    await repository.startHealthUpdates()

    XCTAssertEqual(service.summaryRequests.count, 1)
    XCTAssertEqual(service.startBackgroundDeliveryCount, 1)
    XCTAssertNotNil(service.onChange)
  }

  func testBackgroundUpdateRefreshesAndUsesThrottledWidgetReload() async throws {
    let clock = MutableClock(try makeDate(year: 2026, month: 5, day: 20, hour: 12))
    let service = FakeStepDataService()
    let cache = StepSnapshotCacheSpy()
    service.summariesResult = [
      DayStepSummary(date: clock.current, steps: 1_000, distanceKilometers: 0.75, goal: 7_500)
    ]
    let repository = makeRepository(
      service: service, cache: cache, clock: clock, liveWidgetReloadInterval: 60)

    await repository.startHealthUpdates()
    service.summariesResult = [
      DayStepSummary(date: clock.current, steps: 2_000, distanceKilometers: 1.5, goal: 7_500)
    ]
    await service.onChange?()

    XCTAssertEqual(repository.today.steps, 2_000)
    XCTAssertEqual(cache.reloadRequests, [true, false])
  }

  func testBackgroundUpdateReloadsWidgetsAfterThrottleInterval() async throws {
    let clock = MutableClock(try makeDate(year: 2026, month: 5, day: 20, hour: 12))
    let service = FakeStepDataService()
    let cache = StepSnapshotCacheSpy()
    service.summariesResult = [
      DayStepSummary(date: clock.current, steps: 1_000, distanceKilometers: 0.75, goal: 7_500)
    ]
    let repository = makeRepository(
      service: service, cache: cache, clock: clock, liveWidgetReloadInterval: 60)

    await repository.startHealthUpdates()
    clock.current = try makeDate(year: 2026, month: 5, day: 20, hour: 12, minute: 1, second: 1)
    service.summariesResult = [
      DayStepSummary(date: clock.current, steps: 2_000, distanceKilometers: 1.5, goal: 7_500)
    ]
    await service.onChange?()

    XCTAssertEqual(cache.reloadRequests, [true, true])
  }

  func testRefreshFailureSetsErrorAndKeepsExistingData() async throws {
    let clock = MutableClock(try makeDate(year: 2026, month: 5, day: 20))
    let service = FakeStepDataService()
    let existing = try makeSummary(year: 2026, month: 5, day: 20, steps: 3_000, goal: 7_500)
    service.summariesResult = [existing]
    let repository = makeRepository(service: service, clock: clock)
    await repository.refresh()

    service.summariesError = TestError.sample
    await repository.refresh()

    XCTAssertEqual(repository.days, [existing])
    XCTAssertEqual(repository.errorMessage, TestError.sample.localizedDescription)
    XCTAssertFalse(repository.isLoading)
  }

  func testLoadMoreHistoryRequestsPreviousTwelveMonthsAndMergesDays() async throws {
    let now = try makeDate(year: 2026, month: 5, day: 20)
    let clock = MutableClock(now)
    let service = FakeStepDataService()
    let cache = StepSnapshotCacheSpy()
    let existing = [
      try makeSummary(year: 2026, month: 5, day: 1, steps: 1_000, goal: 7_500),
      try makeSummary(year: 2026, month: 5, day: 2, steps: 2_000, goal: 7_500),
    ]
    service.summariesResult = existing
    let repository = makeRepository(service: service, cache: cache, clock: clock)
    await repository.refresh()

    let older = try makeSummary(year: 2024, month: 5, day: 1, steps: 9_000, goal: 7_500)
    let replacement = try makeSummary(year: 2026, month: 5, day: 1, steps: 5_000, goal: 7_500)
    service.summariesResult = [older, replacement]
    await repository.loadMoreHistory()

    XCTAssertEqual(
      service.summaryRequests.last,
      SummaryRequest(
        start: try makeDate(year: 2024, month: 5, day: 1),
        end: try makeDate(year: 2025, month: 4, day: 30)
      )
    )
    XCTAssertEqual(repository.days, [older, replacement, existing[1]])
  }

  func testTodayFallsBackToCurrentSettingsWhenNoTodayData() throws {
    let clock = MutableClock(try makeDate(year: 2026, month: 5, day: 20))
    let settings = makeSettings()
    settings.replace(history: [
      StepSettingsSnapshot(
        effectiveDate: try makeDate(year: 2026, month: 5, day: 1),
        targetSteps: 8_500
      )
    ])
    let repository = makeRepository(settings: settings, clock: clock)

    XCTAssertEqual(repository.today.date, clock.current)
    XCTAssertEqual(repository.today.steps, 0)
    XCTAssertEqual(repository.today.distanceKilometers, 0)
    XCTAssertEqual(repository.today.goal, 8_500)
  }

  private func makeRepository(
    service: FakeStepDataService,
    settings: StepSettingsStore? = nil,
    cache: StepSnapshotCacheSpy = StepSnapshotCacheSpy(),
    clock: MutableClock,
    liveWidgetReloadInterval: TimeInterval = 60
  ) -> StepRepository {
    StepRepository(
      dataService: service,
      settings: settings ?? makeSettings(),
      snapshotCache: cache,
      calendar: calendar,
      now: clock.now,
      liveWidgetReloadInterval: liveWidgetReloadInterval
    )
  }

  private func makeRepository(
    settings: StepSettingsStore? = nil,
    cache: StepSnapshotCacheSpy = StepSnapshotCacheSpy(),
    clock: MutableClock,
    liveWidgetReloadInterval: TimeInterval = 60
  ) -> StepRepository {
    makeRepository(
      service: FakeStepDataService(),
      settings: settings,
      cache: cache,
      clock: clock,
      liveWidgetReloadInterval: liveWidgetReloadInterval
    )
  }

  private func makeSettings() -> StepSettingsStore {
    let defaults = UserDefaults(
      suiteName: "com.nixypanda.StepCo.repository.tests.\(UUID().uuidString)")!
    return StepSettingsStore(defaults: defaults, calendar: calendar)
  }

  private func makeSummary(year: Int, month: Int, day: Int, steps: Int, goal: Int) throws
    -> DayStepSummary
  {
    DayStepSummary(
      date: try makeDate(year: year, month: month, day: day),
      steps: steps,
      distanceKilometers: Double(steps) * 0.00075,
      goal: goal
    )
  }

  private func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0
  ) throws -> Date {
    try XCTUnwrap(
      calendar.date(
        from: DateComponents(
          year: year,
          month: month,
          day: day,
          hour: hour,
          minute: minute,
          second: second
        )
      )
    )
  }
}

@MainActor
private final class FakeStepDataService: StepDataService {
  var authorizationRequestCount = 0
  var startBackgroundDeliveryCount = 0
  var summaryRequests: [SummaryRequest] = []
  var summariesResult: [DayStepSummary] = []
  var summariesError: Error?
  var onChange: (@MainActor () async -> Void)?
  var summariesHandler:
    ((Date, Date, (Date) -> StepSettingsSnapshot) async throws -> [DayStepSummary])?

  func requestAuthorization() async throws {
    authorizationRequestCount += 1
  }

  func startBackgroundDelivery(
    onChange: @escaping @MainActor () async -> Void
  ) async throws {
    startBackgroundDeliveryCount += 1
    self.onChange = onChange
  }

  func summaries(
    from startDate: Date,
    through endDate: Date,
    settingsForDate: (Date) -> StepSettingsSnapshot
  ) async throws -> [DayStepSummary] {
    summaryRequests.append(SummaryRequest(start: startDate, end: endDate))

    if let summariesError {
      throw summariesError
    }

    if let summariesHandler {
      return try await summariesHandler(startDate, endDate, settingsForDate)
    }

    return summariesResult
  }
}

private struct SummaryRequest: Equatable {
  let start: Date
  let end: Date
}

private final class StepSnapshotCacheSpy: StepSnapshotCaching {
  var savedSnapshots: [CachedStepSnapshot] = []
  var reloadRequests: [Bool] = []
  var loadedSnapshot: CachedStepSnapshot?

  func save(_ snapshot: CachedStepSnapshot, reloadWidgets: Bool) {
    savedSnapshots.append(snapshot)
    reloadRequests.append(reloadWidgets)
  }

  func load() -> CachedStepSnapshot? {
    loadedSnapshot
  }
}

private final class MutableClock {
  var current: Date

  init(_ current: Date) {
    self.current = current
  }

  func now() -> Date {
    current
  }
}

private enum TestError: LocalizedError {
  case sample

  var errorDescription: String? {
    "Sample error"
  }
}
