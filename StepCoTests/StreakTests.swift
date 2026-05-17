import XCTest
@testable import StepCo

@MainActor
final class StreakTests: XCTestCase {
    private func makeRepository() -> StepRepository {
        let id = UUID().uuidString
        let defaults = UserDefaults(suiteName: "com.nixypanda.StepCo.tests.\(id)")!
        return StepRepository(
            settings: StepSettingsStore(defaults: defaults, calendar: .current),
            calendar: .current
        )
    }

    // MARK: - Main test case

    func testStreakSurvivesLeewayAcrossGoalChange() throws {
        let repository = makeRepository()
        let calendar = Calendar.current

        let today = calendar.startOfDay(for: Date())
        let totalDays = 31
        let startDate = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -(totalDays - 1), to: today)
        )

        var days: [DayStepSummary] = []
        var cursor = startDate

        for dayOffset in 0..<totalDays {
            let goal: Int
            let leewayDays: Int
            let steps: Int

            if dayOffset < 10 {
                goal = 7_000
                leewayDays = 0
                steps = 8_000
            } else if dayOffset < 20 {
                goal = 7_000
                leewayDays = 2
                if dayOffset == 12 || dayOffset == 14 {
                    steps = 6_500
                } else {
                    steps = 8_000
                }
            } else {
                goal = 8_000
                leewayDays = 2
                steps = 9_000
            }

            days.append(DayStepSummary(
                date: cursor,
                steps: steps,
                distanceKilometers: Double(steps) * 0.00075,
                goal: goal,
                leewayDays: leewayDays
            ))

            cursor = try XCTUnwrap(
                calendar.date(byAdding: .day, value: 1, to: cursor)
            )
        }

        repository.days = days
        XCTAssertEqual(repository.currentStreak, totalDays)
    }

    // MARK: - Additional edge-case tests

    func testZeroDays() {
        let repository = makeRepository()
        XCTAssertEqual(repository.currentStreak, 0)
    }

    func testStreakBreaksOnFirstMissWithNoLeeway() throws {
        let repository = makeRepository()
        let calendar = Calendar.current

        let today = calendar.startOfDay(for: Date())
        let days: [DayStepSummary] = (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let isMiss = offset == 2
            return DayStepSummary(
                date: date,
                steps: isMiss ? 3_000 : 8_000,
                distanceKilometers: 6,
                goal: 7_000,
                leewayDays: 0
            )
        }

        repository.days = days
        XCTAssertEqual(repository.currentStreak, 2)
    }

    func testLeewayCoversMissesAtEndOfStreak() throws {
        let repository = makeRepository()
        let calendar = Calendar.current

        let today = calendar.startOfDay(for: Date())
        let days: [DayStepSummary] = (0..<6).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let isMiss = offset == 1 || offset == 2
            return DayStepSummary(
                date: date,
                steps: isMiss ? 3_000 : 8_000,
                distanceKilometers: 6,
                goal: 7_000,
                leewayDays: 2
            )
        }

        repository.days = days
        XCTAssertEqual(repository.currentStreak, 6)
    }

    func testLeewayExhaustedBreaksStreak() throws {
        let repository = makeRepository()
        let calendar = Calendar.current

        let today = calendar.startOfDay(for: Date())
        let days: [DayStepSummary] = (0..<6).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DayStepSummary(
                date: date,
                steps: 3_000,
                distanceKilometers: 6,
                goal: 7_000,
                leewayDays: 2
            )
        }

        repository.days = days
        XCTAssertEqual(repository.currentStreak, 2)
    }
}
