import Foundation
import Combine

final class StepSettingsStore: ObservableObject {
    private enum Key {
        static let history = "settingsHistory"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    @Published private(set) var history: [StepSettingsSnapshot]

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar

        if let data = defaults.data(forKey: Key.history),
           let decoded = try? JSONDecoder().decode([StepSettingsSnapshot].self, from: data),
           !decoded.isEmpty {
            history = decoded.sorted { $0.effectiveDate < $1.effectiveDate }
        } else {
            history = [
                StepSettingsSnapshot(
                    effectiveDate: calendar.startOfDay(for: Date()),
                    targetSteps: 7_500
                )
            ]
        }
    }

    var current: StepSettingsSnapshot {
        settings(for: Date())
    }

    var targetSteps: Int {
        current.targetSteps
    }

    func settings(for date: Date) -> StepSettingsSnapshot {
        let day = calendar.startOfDay(for: date)
        return history.last { $0.effectiveDate <= day } ?? history[0]
    }

    func update(targetSteps: Int? = nil) {
        let today = calendar.startOfDay(for: Date())
        let next = StepSettingsSnapshot(
            effectiveDate: today,
            targetSteps: max(1, targetSteps ?? current.targetSteps)
        )

        history.removeAll { calendar.isDate($0.effectiveDate, inSameDayAs: today) }
        history.append(next)
        history.sort { $0.effectiveDate < $1.effectiveDate }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Key.history)
    }
}
