import Foundation
import SwiftUI

enum StepGoalLevel: String, Codable {
    case low
    case warning
    case met

    var color: Color {
        switch self {
        case .low:
            .red
        case .warning:
            .orange
        case .met:
            .green
        }
    }
}

struct DayStepSummary: Identifiable, Codable, Equatable {
    var id: Date { date }

    let date: Date
    let steps: Int
    let distanceKilometers: Double
    let goal: Int

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    var level: StepGoalLevel {
        guard goal > 0 else { return .low }

        if steps >= goal {
            return .met
        }

        if steps >= goal / 2 {
            return .warning
        }

        return .low
    }

    var shortStepsText: String {
        if steps >= 1_000 {
            return "\(steps / 1_000)k"
        }

        return "\(steps)"
    }
}

struct StepSettingsSnapshot: Codable, Equatable {
    let effectiveDate: Date
    let targetSteps: Int
}

struct CachedStepSnapshot: Codable, Equatable {
    let updatedAt: Date
    let today: DayStepSummary
    let currentStreak: Int
}

enum StepFormatters {
    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    static let dayNumber: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    static let weekdaySymbol: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

extension Int {
    var stepText: String {
        StepFormatters.integer.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    var kilometerText: String {
        String(format: "%.2f km", self)
    }
}
