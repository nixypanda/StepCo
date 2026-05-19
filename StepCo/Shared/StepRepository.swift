import Foundation
import Combine

@MainActor
final class StepRepository: ObservableObject {
    private let healthStore: HealthKitStepStore
    private let settings: StepSettingsStore
    private let calendar: Calendar
    private let liveWidgetReloadInterval: TimeInterval = 60
    private let historyPageMonthCount = 12

    @Published var days: [DayStepSummary] = []
    @Published var isLoading = false
    @Published var isLoadingMoreHistory = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private var lastWidgetReload: Date?
    private var historyStartDate: Date?

    init(
        healthStore: HealthKitStepStore? = nil,
        settings: StepSettingsStore,
        calendar: Calendar = .current
    ) {
        self.healthStore = healthStore ?? HealthKitStepStore()
        self.settings = settings
        self.calendar = calendar
    }

    var today: DayStepSummary {
        if let today = days.last(where: { calendar.isDateInToday($0.date) }) {
            return today
        }

        let snapshot = settings.current
        return DayStepSummary(
            date: Date(),
            steps: 0,
            distanceKilometers: 0,
            goal: snapshot.targetSteps
        )
    }

    var currentStreak: Int {
        var streak = 0

        for day in days.sorted(by: { $0.date > $1.date }) {
            guard day.steps >= day.goal else { break }
            streak += 1
        }

        return streak
    }

    func refresh() async {
        await refresh(forceWidgetReload: true)
    }

    func startHealthUpdates() async {
        await refresh(forceWidgetReload: true)

        guard !shouldUseDemoData else { return }

        do {
            try await healthStore.startBackgroundDelivery { [weak self] in
                await self?.refresh(forceWidgetReload: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMoreHistory() async {
        guard !isLoadingMoreHistory else { return }

        if historyStartDate == nil {
            historyStartDate = days.map(\.date).min().map { startOfMonth(for: $0) }
        }

        guard let historyStartDate,
              let start = calendar.date(byAdding: .month, value: -historyPageMonthCount, to: historyStartDate),
              let end = calendar.date(byAdding: .day, value: -1, to: historyStartDate) else {
            return
        }

        isLoadingMoreHistory = true
        errorMessage = nil

        do {
            let olderDays: [DayStepSummary]

            if shouldUseDemoData {
                olderDays = StepDemoData.summaries(from: start, through: end, calendar: calendar) { date in
                    settings.settings(for: date)
                }
            } else {
                try await healthStore.requestAuthorization()
                olderDays = try await healthStore.summaries(from: start, through: end, settings: settings)
            }

            days = merged(days + olderDays)
            self.historyStartDate = startOfMonth(for: start)
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMoreHistory = false
    }

    private func refresh(forceWidgetReload: Bool) async {
        isLoading = true
        errorMessage = nil

        let end = Date()
        let start = historyStartDate ?? initialHistoryStartDate(endingAt: end)

        if shouldUseDemoData {
            days = StepDemoData.summaries(from: start, through: end, calendar: calendar) { date in
                settings.settings(for: date)
            }
            historyStartDate = start
            lastUpdated = Date()
            saveSnapshot(forceWidgetReload: forceWidgetReload)
            isLoading = false
            return
        }

        do {
            try await healthStore.requestAuthorization()
            days = try await healthStore.summaries(from: start, through: end, settings: settings)
            historyStartDate = start
            lastUpdated = Date()
            saveSnapshot(forceWidgetReload: forceWidgetReload)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveSnapshot(forceWidgetReload: Bool) {
        let now = Date()
        let shouldReloadWidgets = forceWidgetReload || shouldReloadWidgets(now: now)

        if shouldReloadWidgets {
            lastWidgetReload = now
        }

        StepSnapshotCache.save(
            CachedStepSnapshot(updatedAt: lastUpdated ?? now, today: today, currentStreak: currentStreak),
            reloadWidgets: shouldReloadWidgets
        )
    }

    private func shouldReloadWidgets(now: Date) -> Bool {
        guard let lastWidgetReload else { return true }
        return now.timeIntervalSince(lastWidgetReload) >= liveWidgetReloadInterval
    }

    private func initialHistoryStartDate(endingAt endDate: Date) -> Date {
        let yearAgo = calendar.date(byAdding: .month, value: -historyPageMonthCount, to: endDate) ?? endDate
        return startOfMonth(for: yearAgo)
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func merged(_ summaries: [DayStepSummary]) -> [DayStepSummary] {
        let byDay = summaries.reduce(into: [Date: DayStepSummary]()) { result, summary in
            result[calendar.startOfDay(for: summary.date)] = summary
        }

        return byDay.values.sorted { $0.date < $1.date }
    }

    private var shouldUseDemoData: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
