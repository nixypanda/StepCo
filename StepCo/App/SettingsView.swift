import SwiftUI

struct SettingsView: View {
  @ObservedObject var settings: StepSettingsStore
  let didChange: () -> Void

  @State private var targetSteps = StepSettingsStore.defaultTargetSteps
  @State private var isHistoryExpanded = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Stepper(value: $targetSteps, in: 1_000...50_000, step: 500) {
            LabeledContent("Target steps", value: "\(targetSteps.stepText)")
          }
        }

        Section {
          DisclosureGroup(isExpanded: $isHistoryExpanded) {
            VStack(spacing: 12) {
              ForEach(settings.displayHistory) { period in
                StepSettingsHistoryRow(period: period)
              }
            }
            .padding(.vertical, 6)
          } label: {
            Label("Target history", systemImage: "clock.arrow.circlepath")
          }
        }

        Section {
          Text("Changes apply from today onward.")
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Settings")
      .onAppear {
        targetSteps = settings.targetSteps
      }
      .onChange(of: targetSteps) { _, newValue in
        settings.update(targetSteps: newValue)
        didChange()
      }
    }
  }
}

private struct StepSettingsHistoryRow: View {
  let period: StepSettingsPeriod

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline)
        Text("\(period.targetSteps.stepText) steps")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      if period.isCurrent {
        Text("Current")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.green)
      }
    }
  }

  private var title: String {
    if period.isCurrent {
      return "Current"
    }

    let end = period.endDate.map(Self.formattedDate) ?? "Current"

    guard let startDate = period.startDate else {
      return "Before \(end)"
    }

    return "\(Self.formattedDate(startDate)) to \(end)"
  }

  private static func formattedDate(_ date: Date) -> String {
    dateFormatter.string(from: date)
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d MMM"
    return formatter
  }()
}
