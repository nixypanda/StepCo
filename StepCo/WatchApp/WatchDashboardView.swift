import SwiftUI

struct WatchDashboardView: View {
    @ObservedObject var settings: StepSettingsStore
    @StateObject private var repository: StepRepository

    init(settings: StepSettingsStore) {
        self.settings = settings
        _repository = StateObject(wrappedValue: StepRepository(settings: settings))
    }

    var body: some View {
        let summary = repository.today

        GeometryReader { proxy in
            ZStack {
                WatchDashboardBackground(color: summary.level.color)

                WatchProgressArc(progress: summary.progress, color: summary.level.color)

                VStack(spacing: 14) {
                    WatchMetricRow(summary: summary)
                        .padding(.top, max(44, proxy.size.height * 0.18))

                    Text(summary.steps.stepText)
                        .font(.system(size: min(66, proxy.size.width * 0.29), weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
            }
        }
        .ignoresSafeArea()
        .task {
            await repository.startHealthUpdates()
        }
        .onChange(of: settings.history) { _, _ in
            Task {
                await repository.refresh()
            }
        }
    }
}

private struct WatchMetricRow: View {
    let summary: DayStepSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(summary.distanceKilometers.watchDistanceText)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("km")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))

            Text("\(summary.estimatedFloors)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("floors")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.76)
    }
}

private struct WatchDashboardBackground: View {
    let color: Color

    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    color.opacity(0.72),
                    color.opacity(0.28),
                    color.opacity(0.08),
                    .black
                ],
                center: .bottom,
                startRadius: 24,
                endRadius: 230
            )
        }
    }
}

private struct WatchProgressArc: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            WatchBottomArc(progress: 1)
                .stroke(color.opacity(0.26), style: StrokeStyle(lineWidth: 50, lineCap: .round))

            WatchBottomArc(progress: progress)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.88), color],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 50, lineCap: .round)
                )
        }
    }
}

private struct WatchBottomArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.66
        let center = CGPoint(x: rect.midX, y: rect.maxY + radius * 0.52)
        let start = 210.0
        let end = 330.0
        let clampedProgress = min(max(progress, 0), 1)
        let progressEnd = start + ((end - start) * clampedProgress)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(progressEnd),
            clockwise: false
        )
        return path
    }
}

private extension DayStepSummary {
    var estimatedFloors: Int {
        max(0, Int((distanceKilometers * 8.2).rounded()))
    }
}

private extension Double {
    var watchDistanceText: String {
        String(format: "%.1f", self)
    }
}
