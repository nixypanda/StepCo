import CoreMotion
import Foundation

struct LivePedometerUpdate {
    let steps: Int
    let distanceKilometers: Double
}

@MainActor
final class LivePedometerStore {
    private let pedometer = CMPedometer()
    private var isRunning = false

    func start(
        from startDate: Date,
        onUpdate: @escaping @MainActor (LivePedometerUpdate) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) {
        guard CMPedometer.isStepCountingAvailable() else { return }

        stop()
        isRunning = true

        pedometer.startUpdates(from: startDate) { data, error in
            Task { @MainActor in
                guard self.isRunning else { return }

                if let error {
                    onError(error.localizedDescription)
                    return
                }

                guard let data else { return }

                onUpdate(
                    LivePedometerUpdate(
                        steps: data.numberOfSteps.intValue,
                        distanceKilometers: (data.distance?.doubleValue ?? 0) / 1_000
                    )
                )
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        pedometer.stopUpdates()
        isRunning = false
    }
}
