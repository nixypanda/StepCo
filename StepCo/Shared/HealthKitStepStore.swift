import Foundation
import HealthKit

@MainActor
final class HealthKitStepStore {
    enum HealthError: LocalizedError {
        case healthDataUnavailable
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .healthDataUnavailable:
                "Health data is unavailable on this device."
            case .authorizationDenied:
                "StepCo needs Health access for steps and walking distance."
            }
        }
    }

    private let store = HKHealthStore()
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.healthDataUnavailable
        }

        let reads: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning)
        ]

        try await store.requestAuthorization(toShare: [], read: reads)
    }

    func summaries(
        from startDate: Date,
        through endDate: Date,
        settings: StepSettingsStore
    ) async throws -> [DayStepSummary] {
        let days = calendar.days(from: startDate, through: endDate)
        async let steps = quantities(for: .stepCount, unit: .count(), days: days)
        async let distance = quantities(for: .distanceWalkingRunning, unit: .meter(), days: days)

        let stepValues = try await steps
        let distanceValues = try await distance

        return days.map { date in
            let snapshot = settings.settings(for: date)
            let meters = distanceValues[calendar.startOfDay(for: date)] ?? 0

            return DayStepSummary(
                date: date,
                steps: Int(stepValues[calendar.startOfDay(for: date)] ?? 0),
                distanceKilometers: meters / 1_000,
                goal: snapshot.targetSteps,
                leewayDays: snapshot.leewayDays
            )
        }
    }

    private func quantities(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: [Date]
    ) async throws -> [Date: Double] {
        guard let firstDay = days.first,
              let lastDay = days.last,
              let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return [:]
        }

        let start = calendar.startOfDay(for: firstDay)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay)) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var values: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    values[self.calendar.startOfDay(for: statistics.startDate)] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                }

                continuation.resume(returning: values)
            }

            store.execute(query)
        }
    }
}

extension Calendar {
    func days(from startDate: Date, through endDate: Date) -> [Date] {
        let start = startOfDay(for: startDate)
        let end = startOfDay(for: endDate)

        var result: [Date] = []
        var cursor = start

        while cursor <= end {
            result.append(cursor)
            guard let next = date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return result
    }
}
