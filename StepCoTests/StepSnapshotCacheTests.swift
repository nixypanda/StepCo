import XCTest

@testable import StepCo

final class StepSnapshotCacheTests: XCTestCase {
  func testSnapshotCacheSavesAndLoadsSnapshot() throws {
    let defaults = makeDefaults()
    let cache = StepSnapshotCache(defaults: defaults, widgetReloader: WidgetReloaderSpy())
    let snapshot = CachedStepSnapshot(
      updatedAt: Date(timeIntervalSince1970: 1_000),
      today: DayStepSummary(
        date: Date(timeIntervalSince1970: 900),
        steps: 4_000,
        distanceKilometers: 3,
        goal: 7_500
      )
    )

    cache.save(snapshot, reloadWidgets: false)

    XCTAssertEqual(cache.load(), snapshot)
  }

  func testSnapshotCacheReturnsNilForMissingSnapshot() {
    let cache = StepSnapshotCache(defaults: makeDefaults(), widgetReloader: WidgetReloaderSpy())

    XCTAssertNil(cache.load())
  }

  func testSnapshotCacheReturnsNilForInvalidStoredData() {
    let defaults = makeDefaults()
    defaults.set(Data("invalid".utf8), forKey: StepSnapshotCache.key)
    let cache = StepSnapshotCache(defaults: defaults, widgetReloader: WidgetReloaderSpy())

    XCTAssertNil(cache.load())
  }

  func testSnapshotCacheReloadsWidgetsOnlyWhenRequested() {
    let reloader = WidgetReloaderSpy()
    let cache = StepSnapshotCache(defaults: makeDefaults(), widgetReloader: reloader)
    let snapshot = CachedStepSnapshot(
      updatedAt: Date(),
      today: DayStepSummary(date: Date(), steps: 1, distanceKilometers: 0, goal: 1)
    )

    cache.save(snapshot, reloadWidgets: false)
    cache.save(snapshot, reloadWidgets: true)

    XCTAssertEqual(reloader.reloadCount, 1)
  }

  private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "com.nixypanda.StepCo.cache.tests.\(UUID().uuidString)")!
  }
}

private final class WidgetReloaderSpy: WidgetTimelineReloading {
  var reloadCount = 0

  func reloadStepWidgets() {
    reloadCount += 1
  }
}
