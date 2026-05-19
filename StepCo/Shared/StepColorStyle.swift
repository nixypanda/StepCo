import SwiftUI

struct StepTint {
  let level: StepGoalLevel

  var color: Color {
    level.color
  }

  var softBackground: Color {
    color.opacity(0.14)
  }
}

extension View {
  func stepTint(_ level: StepGoalLevel) -> some View {
    tint(StepTint(level: level).color)
  }
}
