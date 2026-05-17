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

    func testZeroDays() {
        let repository = makeRepository()
        XCTAssertEqual(repository.currentStreak, 0)
    }

    func testStreakBreaksOnFirstMiss() throws {
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
                goal: 7_000
            )
        }

        repository.days = days
        XCTAssertEqual(repository.currentStreak, 2)
    }

    func testAllDaysMet() throws {
        let repository = makeRepository()
        let calendar = Calendar.current

        let today = calendar.startOfDay(for: Date())
        let days: [DayStepSummary] = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return DayStepSummary(
                date: date,
                steps: 8_000,
                distanceKilometers: 6,
                goal: 7_000
            )
        }

        repository.days = days
        XCTAssertEqual(repository.currentStreak, 7)
    }

    func testStreakCrossesGoalChange() throws {
        let repository = makeRepository()
        let calendar = Calendar.current

        let today = calendar.startOfDay(for: Date())
        let days: [DayStepSummary] = (0..<10).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let goal = offset < 5 ? 7_000 : 8_000
            return DayStepSummary(
                date: date,
                steps: goal + 500,
                distanceKilometers: 6,
                goal: goal
            )
        }

        repository.days = days
        XCTAssertEqual(repository.currentStreak, 10)
    }
}
