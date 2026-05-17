import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: StepSettingsStore
    let didChange: () -> Void

    @State private var targetSteps = 7_500

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $targetSteps, in: 1_000...50_000, step: 500) {
                        LabeledContent("Target steps", value: "\(targetSteps.stepText)")
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
