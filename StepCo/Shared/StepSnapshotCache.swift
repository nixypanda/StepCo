import Foundation

enum StepSnapshotCache {
    static let suiteName = "group.com.nixypanda.StepCo"
    private static let key = "cachedStepSnapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func save(_ snapshot: CachedStepSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> CachedStepSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedStepSnapshot.self, from: data)
    }
}
