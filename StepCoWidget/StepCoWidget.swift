import SwiftUI
import WidgetKit

struct StepCoWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: CachedStepSnapshot?
}

struct StepCoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepCoWidgetEntry {
        StepCoWidgetEntry(date: Date(), snapshot: sampleSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepCoWidgetEntry) -> Void) {
        completion(StepCoWidgetEntry(date: Date(), snapshot: StepSnapshotCache.load() ?? sampleSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepCoWidgetEntry>) -> Void) {
        let entry = StepCoWidgetEntry(date: Date(), snapshot: StepSnapshotCache.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private var sampleSnapshot: CachedStepSnapshot {
        StepDemoData.sampleSnapshot()
    }
}

struct StepCoWidgetView: View {
    let entry: StepCoWidgetEntry

    var body: some View {
        if let summary = entry.snapshot?.today {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.title3)

                Text(summary.steps.stepText)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)

                Text(summary.distanceKilometers.kilometerText)
                    .font(.headline)

                ProgressView(value: summary.progress)
                    .stepTint(summary.level)
            }
            .foregroundStyle(summary.level.color)
            .containerBackground(summary.level.color.opacity(0.16), for: .widget)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "figure.walk")
                Text("No steps yet")
                    .font(.headline)
            }
            .containerBackground(.background, for: .widget)
        }
    }
}

struct StepCoWidget: Widget {
    let kind = "StepCoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StepCoWidgetProvider()) { entry in
            StepCoWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Shows today's step count and distance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct StepCoWidgetBundle: WidgetBundle {
    var body: some Widget {
        StepCoWidget()
    }
}
