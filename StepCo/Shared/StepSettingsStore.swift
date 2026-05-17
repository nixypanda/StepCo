import Foundation
import Combine

final class StepSettingsStore: ObservableObject {
    private enum Key {
        static let history = "settingsHistory"
    }

    static let defaultTargetSteps = 7_500
    static let preInstallTargetSteps = 5_000

    private let defaults: UserDefaults
    private let calendar: Calendar

    @Published private(set) var history: [StepSettingsSnapshot]

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar

        if let data = defaults.data(forKey: Key.history),
           let decoded = try? JSONDecoder().decode([StepSettingsSnapshot].self, from: data),
           !decoded.isEmpty {
            history = Self.normalized(history: decoded, calendar: calendar)
        } else {
            history = Self.normalized(history: Self.defaultHistory(calendar: calendar), calendar: calendar)
        }
    }

    private static func defaultHistory(calendar: Calendar) -> [StepSettingsSnapshot] {
        #if targetEnvironment(simulator)
        let today = calendar.startOfDay(for: Date())
        guard
            let first = calendar.date(byAdding: .month, value: -2, to: today),
            let second = calendar.date(byAdding: .day, value: 8, to: first),
            let third = calendar.date(byAdding: .day, value: 18, to: first),
            let fourth = calendar.date(byAdding: .day, value: 31, to: first),
            let fifth = calendar.date(byAdding: .day, value: 44, to: first),
            let sixth = calendar.date(byAdding: .day, value: 54, to: first),
            let seventh = calendar.date(byAdding: .day, value: 54, to: first)
        else {
            return [
                StepSettingsSnapshot(effectiveDate: today, targetSteps: defaultTargetSteps)
            ]
        }

        return [
            StepSettingsSnapshot(effectiveDate: calendar.startOfDay(for: first), targetSteps: defaultTargetSteps),
            StepSettingsSnapshot(effectiveDate: calendar.startOfDay(for: second), targetSteps: 6_000),
            StepSettingsSnapshot(effectiveDate: calendar.startOfDay(for: third), targetSteps: 8_000),
            StepSettingsSnapshot(effectiveDate: calendar.startOfDay(for: fourth), targetSteps: 5_000),
            StepSettingsSnapshot(effectiveDate: calendar.startOfDay(for: fifth), targetSteps: 9_000),
            StepSettingsSnapshot(effectiveDate: calendar.startOfDay(for: sixth), targetSteps: 6_500),
            StepSettingsSnapshot(effectiveDate: calendar.startOfDay(for: seventh), targetSteps: 10_000)
        ]
        #else
        return [
            StepSettingsSnapshot(
                effectiveDate: calendar.startOfDay(for: Date()),
                targetSteps: defaultTargetSteps
            )
        ]
        #endif
    }

    private static func normalized(
        history: [StepSettingsSnapshot],
        calendar: Calendar
    ) -> [StepSettingsSnapshot] {
        let byDay = history.reduce(into: [Date: StepSettingsSnapshot]()) { result, snapshot in
            result[calendar.startOfDay(for: snapshot.effectiveDate)] = StepSettingsSnapshot(
                effectiveDate: calendar.startOfDay(for: snapshot.effectiveDate),
                targetSteps: snapshot.targetSteps
            )
        }

        return byDay.values.sorted { $0.effectiveDate < $1.effectiveDate }
    }

    var displayHistory: [StepSettingsPeriod] {
        guard let first = history.first else {
            return []
        }

        var periods = [
            StepSettingsPeriod(
                startDate: nil,
                endDate: first.effectiveDate,
                targetSteps: Self.preInstallTargetSteps,
                isCurrent: false
            )
        ]

        for index in history.indices {
            periods.append(
                StepSettingsPeriod(
                    startDate: history[index].effectiveDate,
                    endDate: history.indices.contains(index + 1) ? history[index + 1].effectiveDate : nil,
                    targetSteps: history[index].targetSteps,
                    isCurrent: index == history.index(before: history.endIndex)
                )
            )
        }

        return periods
    }

    var current: StepSettingsSnapshot {
        settings(for: Date())
    }

    var targetSteps: Int {
        current.targetSteps
    }

    func settings(for date: Date) -> StepSettingsSnapshot {
        let day = calendar.startOfDay(for: date)

        guard let snapshot = history.last(where: { $0.effectiveDate <= day }) else {
            return StepSettingsSnapshot(effectiveDate: day, targetSteps: Self.preInstallTargetSteps)
        }

        return snapshot
    }

    func update(targetSteps: Int? = nil) {
        let today = calendar.startOfDay(for: Date())
        let next = StepSettingsSnapshot(
            effectiveDate: today,
            targetSteps: max(1, targetSteps ?? current.targetSteps)
        )

        history.removeAll { calendar.isDate($0.effectiveDate, inSameDayAs: today) }
        history.append(next)
        history = Self.normalized(history: history, calendar: calendar)
        persist()
    }

    func replace(history newHistory: [StepSettingsSnapshot]) {
        let sortedHistory = Self.normalized(history: newHistory, calendar: calendar)
        guard !sortedHistory.isEmpty, sortedHistory != history else { return }

        history = sortedHistory
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Key.history)
    }
}

struct StepSettingsPeriod: Identifiable, Equatable {
    var id: Date { startDate ?? .distantPast }

    let startDate: Date?
    let endDate: Date?
    let targetSteps: Int
    let isCurrent: Bool
}
