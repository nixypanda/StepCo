import Foundation

#if canImport(HealthKit)
  import HealthKit
#endif

@MainActor
protocol StepDataService {
  func requestAuthorization() async throws

  func startBackgroundDelivery(
    onChange: @escaping @MainActor () async -> Void
  ) async throws

  func summaries(
    from startDate: Date,
    through endDate: Date,
    settingsForDate: (Date) -> StepSettingsSnapshot
  ) async throws -> [DayStepSummary]
}

@MainActor
struct DemoStepDataService: StepDataService {
  private let calendar: Calendar

  init(calendar: Calendar = .current) {
    self.calendar = calendar
  }

  func requestAuthorization() async throws {}

  func startBackgroundDelivery(
    onChange: @escaping @MainActor () async -> Void
  ) async throws {}

  func summaries(
    from startDate: Date,
    through endDate: Date,
    settingsForDate: (Date) -> StepSettingsSnapshot
  ) async throws -> [DayStepSummary] {
    StepDemoData.summaries(
      from: startDate,
      through: endDate,
      calendar: calendar,
      settingsForDate: settingsForDate
    )
  }
}

enum StepDemoData {
  private static let todaySteps = 5_500
  private static let highRecentHistoricalSteps = 21_500
  private static let minimumHistoricalSteps = 3_000
  private static let maximumHistoricalSteps = 10_000

  static func summaries(
    from startDate: Date,
    through endDate: Date,
    calendar: Calendar = .current,
    settingsForDate: (Date) -> StepSettingsSnapshot
  ) -> [DayStepSummary] {
    days(from: startDate, through: endDate, calendar: calendar).map { date in
      let snapshot = settingsForDate(date)
      let steps = stepsForDemoDay(date, calendar: calendar)

      return DayStepSummary(
        date: date,
        steps: steps,
        distanceKilometers: distanceKilometers(for: steps),
        goal: snapshot.targetSteps
      )
    }
  }

  static func sampleSnapshot() -> CachedStepSnapshot {
    let today = DayStepSummary(
      date: Date(),
      steps: todaySteps,
      distanceKilometers: distanceKilometers(for: todaySteps),
      goal: StepSettingsStore.defaultTargetSteps
    )
    return CachedStepSnapshot(updatedAt: Date(), today: today)
  }

  private static func stepsForDemoDay(_ date: Date, calendar: Calendar) -> Int {
    if calendar.isDateInToday(date) {
      return todaySteps
    }

    if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
      calendar.isDate(date, inSameDayAs: yesterday)
    {
      return highRecentHistoricalSteps
    }

    let day =
      calendar.ordinality(of: .day, in: .era, for: date) ?? calendar.component(.day, from: date)
    let range = maximumHistoricalSteps - minimumHistoricalSteps
    let offset = (day * 1_103 + 7_917) % (range + 1)
    return minimumHistoricalSteps + offset
  }

  private static func distanceKilometers(for steps: Int) -> Double {
    Double(steps) * 0.00075
  }

  private static func days(from startDate: Date, through endDate: Date, calendar: Calendar)
    -> [Date]
  {
    let start = calendar.startOfDay(for: startDate)
    let end = calendar.startOfDay(for: endDate)

    var result: [Date] = []
    var cursor = start

    while cursor <= end {
      result.append(cursor)
      guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
      cursor = next
    }

    return result
  }
}

#if canImport(HealthKit)
  @MainActor
  final class HealthKitStepStore: StepDataService {
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
    private var observerQueries: [HKObserverQuery] = []

    init(calendar: Calendar = .current) {
      self.calendar = calendar
    }

    func requestAuthorization() async throws {
      guard HKHealthStore.isHealthDataAvailable() else {
        throw HealthError.healthDataUnavailable
      }

      let reads = Set<HKObjectType>(quantityTypes)

      try await store.requestAuthorization(toShare: [], read: reads)
    }

    func startBackgroundDelivery(onChange: @escaping @MainActor () async -> Void) async throws {
      guard HKHealthStore.isHealthDataAvailable() else {
        throw HealthError.healthDataUnavailable
      }

      for type in quantityTypes {
        try await enableBackgroundDelivery(for: type)
      }

      guard observerQueries.isEmpty else { return }

      observerQueries = quantityTypes.map { type in
        let query = HKObserverQuery(sampleType: type, predicate: nil) {
          _, completionHandler, error in
          guard error == nil else {
            completionHandler()
            return
          }

          Task {
            await onChange()
            completionHandler()
          }
        }

        store.execute(query)
        return query
      }
    }

    func summaries(
      from startDate: Date,
      through endDate: Date,
      settingsForDate: (Date) -> StepSettingsSnapshot
    ) async throws -> [DayStepSummary] {
      let days = calendar.days(from: startDate, through: endDate)
      async let steps = quantities(for: .stepCount, unit: .count(), days: days)
      async let distance = quantities(for: .distanceWalkingRunning, unit: .meter(), days: days)

      let stepValues = try await steps
      let distanceValues = try await distance

      return days.map { date in
        let snapshot = settingsForDate(date)
        let meters = distanceValues[calendar.startOfDay(for: date)] ?? 0

        return DayStepSummary(
          date: date,
          steps: Int(stepValues[calendar.startOfDay(for: date)] ?? 0),
          distanceKilometers: meters / 1_000,
          goal: snapshot.targetSteps
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
        let type = HKQuantityType.quantityType(forIdentifier: identifier)
      else {
        return [:]
      }

      let start = calendar.startOfDay(for: firstDay)
      let end =
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDay)) ?? Date()
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
            values[self.calendar.startOfDay(for: statistics.startDate)] =
              statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
          }

          continuation.resume(returning: values)
        }

        store.execute(query)
      }
    }

    private var quantityTypes: [HKQuantityType] {
      [
        HKQuantityType(.stepCount),
        HKQuantityType(.distanceWalkingRunning),
      ]
    }

    private func enableBackgroundDelivery(for type: HKQuantityType) async throws {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, Error>) in
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
          if let error {
            continuation.resume(throwing: error)
            return
          }

          if success {
            continuation.resume()
          } else {
            continuation.resume(throwing: HealthError.authorizationDenied)
          }
        }
      }
    }
  }
#endif

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
