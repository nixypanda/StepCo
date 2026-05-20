import Foundation

#if canImport(WidgetKit)
  import WidgetKit
#endif

protocol StepSnapshotCaching {
  func save(_ snapshot: CachedStepSnapshot, reloadWidgets: Bool)
  func load() -> CachedStepSnapshot?
}

protocol WidgetTimelineReloading {
  func reloadStepWidgets()
}

struct WidgetTimelineReloader: WidgetTimelineReloading {
  func reloadStepWidgets() {
    #if canImport(WidgetKit)
      WidgetCenter.shared.reloadTimelines(ofKind: "StepCoWidget")
      WidgetCenter.shared.reloadTimelines(ofKind: "StepCoWatchWidget")
    #endif
  }
}

final class StepSnapshotCache: StepSnapshotCaching {
  static let suiteName = "group.com.nixypanda.StepCo"
  static let key = "cachedStepSnapshot"
  static let live = StepSnapshotCache()

  private let defaults: UserDefaults
  private let widgetReloader: WidgetTimelineReloading

  init(
    defaults: UserDefaults = UserDefaults(suiteName: StepSnapshotCache.suiteName) ?? .standard,
    widgetReloader: WidgetTimelineReloading = WidgetTimelineReloader()
  ) {
    self.defaults = defaults
    self.widgetReloader = widgetReloader
  }

  func save(_ snapshot: CachedStepSnapshot, reloadWidgets: Bool = true) {
    guard let data = try? JSONEncoder().encode(snapshot) else { return }
    defaults.set(data, forKey: Self.key)

    if reloadWidgets {
      widgetReloader.reloadStepWidgets()
    }
  }

  func load() -> CachedStepSnapshot? {
    guard let data = defaults.data(forKey: Self.key) else { return nil }
    return try? JSONDecoder().decode(CachedStepSnapshot.self, from: data)
  }

  static func save(_ snapshot: CachedStepSnapshot, reloadWidgets: Bool = true) {
    live.save(snapshot, reloadWidgets: reloadWidgets)
  }

  static func load() -> CachedStepSnapshot? {
    live.load()
  }
}
