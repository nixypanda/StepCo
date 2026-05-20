import Combine
import Foundation
import WatchConnectivity

protocol StepSettingsSyncSession: AnyObject {
  var activationState: WCSessionActivationState { get }
  var receivedApplicationContext: [String: Any] { get }
  var delegate: WCSessionDelegate? { get set }

  func activate()
  func updateApplicationContext(_ applicationContext: [String: Any]) throws
}

extension WCSession: StepSettingsSyncSession {}

final class StepSettingsSync: NSObject, ObservableObject {
  private enum Key {
    static let settingsHistory = "settingsHistory"
  }

  private let settings: StepSettingsStore
  private let session: StepSettingsSyncSession?
  private let publishesSettings: Bool
  private var cancellable: AnyCancellable?

  init(
    settings: StepSettingsStore,
    session: StepSettingsSyncSession? = WCSession.isSupported() ? WCSession.default : nil,
    publishesSettings: Bool = StepSettingsSyncDefaults.publishesSettings
  ) {
    self.settings = settings
    self.session = session
    self.publishesSettings = publishesSettings
    super.init()

    guard let session else { return }

    session.delegate = self
    session.activate()

    cancellable = settings.$history
      .dropFirst()
      .sink { [weak self] _ in
        self?.publishSettings()
      }
  }

  private func publishSettings() {
    guard publishesSettings else { return }
    guard let session, session.activationState == .activated else { return }
    guard let data = try? JSONEncoder().encode(settings.history) else { return }

    try? session.updateApplicationContext([
      Key.settingsHistory: data
    ])
  }

  private func applySettings(from applicationContext: [String: Any]) {
    guard let data = applicationContext[Key.settingsHistory] as? Data,
      let history = try? JSONDecoder().decode([StepSettingsSnapshot].self, from: data)
    else {
      return
    }

    DispatchQueue.main.async { [settings] in
      settings.replace(history: history)
    }
  }
}

extension StepSettingsSync: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated else { return }
    applySettings(from: session.receivedApplicationContext)
    publishSettings()
  }

  func session(
    _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    applySettings(from: applicationContext)
  }

  #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
      session.activate()
    }
  #endif
}

private enum StepSettingsSyncDefaults {
  #if os(iOS)
    static let publishesSettings = true
  #else
    static let publishesSettings = false
  #endif
}
