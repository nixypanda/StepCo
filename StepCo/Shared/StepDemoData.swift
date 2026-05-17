import Foundation

enum StepDemoData {
    private static let todaySteps = 5_500

    static func summaries(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar = .current,
        settingsForDate: (Date) -> StepSettingsSnapshot
    ) -> [DayStepSummary] {
        days(from: startDate, through: endDate, calendar: calendar).map { date in
            let snapshot = settingsForDate(date)
            let steps = stepsForDemoDay(date, goal: snapshot.targetSteps, calendar: calendar)

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

    private static func stepsForDemoDay(_ date: Date, goal: Int, calendar: Calendar) -> Int {
        if calendar.isDateInToday(date) {
            return todaySteps
        }

        let day = calendar.component(.day, from: date)
        let ratios: [Double] = [0.38, 0.52, 0.74, 0.91, 1.04, 0.67, 1.12]
        return Int((Double(goal) * ratios[day % ratios.count]).rounded())
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
