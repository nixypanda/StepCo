import SwiftUI
import WidgetKit

struct StepCoWatchWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: CachedStepSnapshot?
}

struct StepCoWatchWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepCoWatchWidgetEntry {
        StepCoWatchWidgetEntry(date: Date(), snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepCoWatchWidgetEntry) -> Void) {
        completion(StepCoWatchWidgetEntry(date: Date(), snapshot: StepSnapshotCache.load() ?? sampleSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepCoWatchWidgetEntry>) -> Void) {
        let entry = StepCoWatchWidgetEntry(date: Date(), snapshot: StepSnapshotCache.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var sampleSnapshot: CachedStepSnapshot {
        StepDemoData.sampleSnapshot()
    }
}

struct StepCoWatchWidgetView: View {
    let entry: StepCoWatchWidgetEntry

    var body: some View {
        let summary = entry.snapshot?.today ?? DayStepSummary(date: Date(), steps: 0, distanceKilometers: 0, goal: 7_500)

        Gauge(value: summary.progress) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(summary.shortStepsText)
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .stepTint(summary.level)
        .containerBackground(summary.level.color.opacity(0.16), for: .widget)
    }
}

struct StepCoWatchWidget: Widget {
    let kind = "StepCoWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepCoWatchWidgetProvider()) { entry in
            StepCoWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Shows today's step progress.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

@main
struct StepCoWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepCoWatchWidget()
    }
}
