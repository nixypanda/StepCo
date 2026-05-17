import Foundation

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
            goal: 7_500
        )
        return CachedStepSnapshot(updatedAt: Date(), today: today, currentStreak: 0)
    }

    private static func stepsForDemoDay(_ date: Date, calendar: Calendar) -> Int {
        if calendar.isDateInToday(date) {
            return todaySteps
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return highRecentHistoricalSteps
        }

        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? calendar.component(.day, from: date)
        let range = maximumHistoricalSteps - minimumHistoricalSteps
        let offset = (day * 1_103 + 7_917) % (range + 1)
        return minimumHistoricalSteps + offset
    }

    private static func distanceKilometers(for steps: Int) -> Double {
        Double(steps) * 0.00075
    }

    private static func days(from startDate: Date, through endDate: Date, calendar: Calendar) -> [Date] {
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
