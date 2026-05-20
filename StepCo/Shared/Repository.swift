import Combine
import Foundation

@MainActor
final class StepRepository: ObservableObject {
  private let dataService: StepDataService
  private let settings: StepSettingsProviding
  private let snapshotCache: StepSnapshotCaching
  private let calendar: Calendar
  private let now: () -> Date
  private let liveWidgetReloadInterval: TimeInterval
  private let historyPageMonthCount = 12

  @Published var days: [DayStepSummary] = []
  @Published var isLoading = false
  @Published var isLoadingMoreHistory = false
  @Published var errorMessage: String?
  @Published var lastUpdated: Date?

  private var lastWidgetReload: Date?
  private var historyStartDate: Date?

  init(
    dataService: StepDataService,
    settings: StepSettingsProviding,
    snapshotCache: StepSnapshotCaching = StepSnapshotCache.live,
    calendar: Calendar = .current,
    now: @escaping () -> Date = Date.init,
    liveWidgetReloadInterval: TimeInterval = 60
  ) {
    self.dataService = dataService
    self.settings = settings
    self.snapshotCache = snapshotCache
    self.calendar = calendar
    self.now = now
    self.liveWidgetReloadInterval = liveWidgetReloadInterval
  }

  static func production(
    settings: StepSettingsProviding,
    snapshotCache: StepSnapshotCaching = StepSnapshotCache.live,
    calendar: Calendar = .current,
    now: @escaping () -> Date = Date.init
  ) -> StepRepository {
    #if targetEnvironment(simulator)
      let dataService: StepDataService = DemoStepDataService(calendar: calendar)
    #else
      let dataService: StepDataService = HealthKitStepStore(calendar: calendar)
    #endif

    return StepRepository(
      dataService: dataService,
      settings: settings,
      snapshotCache: snapshotCache,
      calendar: calendar,
      now: now
    )
  }

  var today: DayStepSummary {
    if let today = days.last(where: { calendar.isDate($0.date, inSameDayAs: now()) }) {
      return today
    }

    let snapshot = settings.current
    return DayStepSummary(
      date: now(),
      steps: 0,
      distanceKilometers: 0,
      goal: snapshot.targetSteps
    )
  }

  func refresh() async {
    await refresh(forceWidgetReload: true)
  }

  func startHealthUpdates() async {
    await refresh(forceWidgetReload: true)

    do {
      try await dataService.startBackgroundDelivery { [weak self] in
        await self?.refresh(forceWidgetReload: false)
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
      let start = calendar.date(
        byAdding: .month, value: -historyPageMonthCount, to: historyStartDate),
      let end = calendar.date(byAdding: .day, value: -1, to: historyStartDate)
    else {
      return
    }

    isLoadingMoreHistory = true
    errorMessage = nil

    do {
      try await dataService.requestAuthorization()
      let olderDays = try await dataService.summaries(
        from: start,
        through: end
      ) { [settings] date in
        settings.settings(for: date)
      }

      days = merged(days + olderDays)
      self.historyStartDate = startOfMonth(for: start)
      lastUpdated = now()
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoadingMoreHistory = false
  }

  private func refresh(forceWidgetReload: Bool) async {
    isLoading = true
    errorMessage = nil

    let end = now()
    let start = historyStartDate ?? initialHistoryStartDate(endingAt: end)

    do {
      try await dataService.requestAuthorization()
      days = try await dataService.summaries(
        from: start,
        through: end
      ) { [settings] date in
        settings.settings(for: date)
      }
      historyStartDate = start
      lastUpdated = now()
      saveSnapshot(forceWidgetReload: forceWidgetReload)
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  private func saveSnapshot(forceWidgetReload: Bool) {
    let currentDate = now()
    let shouldReloadWidgets = forceWidgetReload || shouldReloadWidgets(now: currentDate)

    if shouldReloadWidgets {
      lastWidgetReload = currentDate
    }

    snapshotCache.save(
      CachedStepSnapshot(updatedAt: lastUpdated ?? currentDate, today: today),
      reloadWidgets: shouldReloadWidgets
    )
  }

  private func shouldReloadWidgets(now: Date) -> Bool {
    guard let lastWidgetReload else { return true }
    return now.timeIntervalSince(lastWidgetReload) >= liveWidgetReloadInterval
  }

  private func initialHistoryStartDate(endingAt endDate: Date) -> Date {
    let yearAgo =
      calendar.date(byAdding: .month, value: -historyPageMonthCount, to: endDate) ?? endDate
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
}
