import Foundation
import Combine

@MainActor
final class StepRepository: ObservableObject {
    private let healthStore: HealthKitStepStore
    private let settings: StepSettingsStore
    private let calendar: Calendar
    private let liveWidgetReloadInterval: TimeInterval = 60

    @Published var days: [DayStepSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private var lastWidgetReload: Date?

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

    private func refresh(forceWidgetReload: Bool) async {
        isLoading = true
        errorMessage = nil

        if shouldUseDemoData {
            let end = Date()
            let start = calendar.date(byAdding: .month, value: -12, to: end) ?? end
            days = StepDemoData.summaries(from: start, through: end, calendar: calendar) { date in
                settings.settings(for: date)
            }
            lastUpdated = Date()
            saveSnapshot(forceWidgetReload: forceWidgetReload)
            isLoading = false
            return
        }

        do {
            try await healthStore.requestAuthorization()
            let end = Date()
            let start = calendar.date(byAdding: .month, value: -12, to: end) ?? end
            days = try await healthStore.summaries(from: start, through: end, settings: settings)
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

    private var shouldUseDemoData: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }
}
