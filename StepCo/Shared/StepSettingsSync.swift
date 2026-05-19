import Combine
import Foundation

#if canImport(WatchConnectivity)
  import WatchConnectivity
#endif

#if canImport(WatchConnectivity)
  final class StepSettingsSync: NSObject, ObservableObject {
    private enum Key {
      static let settingsHistory = "settingsHistory"
    }

    private let settings: StepSettingsStore
    private var cancellable: AnyCancellable?

    init(settings: StepSettingsStore) {
      self.settings = settings
      super.init()

      guard WCSession.isSupported() else { return }

      WCSession.default.delegate = self
      WCSession.default.activate()

      cancellable = settings.$history
        .dropFirst()
        .sink { [weak self] _ in
          self?.publishSettings()
        }
    }

    private func publishSettings() {
      #if os(iOS)
        guard WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(settings.history) else { return }

        try? WCSession.default.updateApplicationContext([
          Key.settingsHistory: data
        ])
      #endif
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
#else
  final class StepSettingsSync: ObservableObject {
    init(settings: StepSettingsStore) {}
  }
#endif
