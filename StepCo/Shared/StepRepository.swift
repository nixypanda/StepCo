import Foundation
import Combine

@MainActor
final class StepRepository: ObservableObject {
    private let healthStore: HealthKitStepStore
    private let settings: StepSettingsStore
    private let calendar: Calendar

    @Published var days: [DayStepSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

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
            goal: snapshot.targetSteps,
            leewayDays: snapshot.leewayDays
        )
    }

    var currentStreak: Int {
        var streak = 0
        var leewayRemaining = today.leewayDays

        for day in days.sorted(by: { $0.date > $1.date }) {
            if day.steps >= day.goal {
                streak += 1
                continue
            }

            if leewayRemaining > 0 {
                leewayRemaining -= 1
                streak += 1
                continue
            }

            break
        }

        return streak
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            try await healthStore.requestAuthorization()
            let end = Date()
            let start = calendar.date(byAdding: .month, value: -12, to: end) ?? end
            days = try await healthStore.summaries(from: start, through: end, settings: settings)
            lastUpdated = Date()
            StepSnapshotCache.save(CachedStepSnapshot(updatedAt: lastUpdated ?? Date(), today: today, currentStreak: currentStreak))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
