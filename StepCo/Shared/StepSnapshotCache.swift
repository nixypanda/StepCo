import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum StepSnapshotCache {
    static let suiteName = "group.com.nixypanda.StepCo"
    private static let key = "cachedStepSnapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func save(_ snapshot: CachedStepSnapshot, reloadWidgets: Bool = true) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)

        if reloadWidgets {
            reloadWidgetTimelines()
        }
    }

    static func load() -> CachedStepSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedStepSnapshot.self, from: data)
    }

    private static func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "StepCoWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "StepCoWatchWidget")
        #endif
    }
}
