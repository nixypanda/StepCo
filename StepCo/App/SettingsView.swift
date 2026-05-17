import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: StepSettingsStore
    let didChange: () -> Void

    @State private var targetSteps = 7_500
    @State private var leewayDays = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $targetSteps, in: 1_000...50_000, step: 500) {
                        LabeledContent("Target steps", value: "\(targetSteps.stepText)")
                    }

                    Stepper(value: $leewayDays, in: 0...14) {
                        LabeledContent("Days of leeway", value: "\(leewayDays)")
                    }
                }

                Section {
                    Text("Changes apply from today onward. Past days keep the target and leeway that were active then.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                targetSteps = settings.targetSteps
                leewayDays = settings.leewayDays
            }
            .onChange(of: targetSteps) { _, newValue in
                settings.update(targetSteps: newValue)
                didChange()
            }
            .onChange(of: leewayDays) { _, newValue in
                settings.update(leewayDays: newValue)
                didChange()
            }
        }
    }
}
