import XCTest

@testable import StepCo

#if canImport(WatchConnectivity)
  import WatchConnectivity

  final class StepSettingsSyncTests: XCTestCase {
    private var calendar: Calendar {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(secondsFromGMT: 0)!
      return calendar
    }

    func testSettingsSyncPublishesHistoryChangesThroughInjectedSession() throws {
      let session = FakeSettingsSyncSession()
      let store = makeStore()
      let publishExpectation = expectation(description: "Publishes settings")
      var didFulfill = false
      session.onUpdateApplicationContext = { context in
        XCTAssertNotNil(context["settingsHistory"] as? Data)
        if !didFulfill {
          didFulfill = true
          publishExpectation.fulfill()
        }
      }
      let sync = StepSettingsSync(settings: store, session: session)

      store.update(targetSteps: 8_000)

      wait(for: [publishExpectation], timeout: 1)
      XCTAssertEqual(session.activateCount, 1)
      _ = sync
    }

    func testSettingsSyncDoesNotPublishWhenSessionIsInactive() {
      let session = FakeSettingsSyncSession()
      session.activationState = .inactive
      let store = makeStore()
      _ = StepSettingsSync(settings: store, session: session)

      store.update(targetSteps: 8_000)

      XCTAssertTrue(session.updatedContexts.isEmpty)
    }

    private func makeStore() -> StepSettingsStore {
      let defaults = UserDefaults(
        suiteName: "com.nixypanda.StepCo.sync.tests.\(UUID().uuidString)")!
      return StepSettingsStore(defaults: defaults, calendar: calendar)
    }
  }

  private final class FakeSettingsSyncSession: StepSettingsSyncSession {
    var activationState: WCSessionActivationState = .activated
    var receivedApplicationContext: [String: Any] = [:]
    weak var delegate: WCSessionDelegate?
    var activateCount = 0
    var updatedContexts: [[String: Any]] = []
    var onUpdateApplicationContext: (([String: Any]) -> Void)?

    func activate() {
      activateCount += 1
    }

    func updateApplicationContext(_ applicationContext: [String: Any]) throws {
      updatedContexts.append(applicationContext)
      onUpdateApplicationContext?(applicationContext)
    }
  }
#endif
