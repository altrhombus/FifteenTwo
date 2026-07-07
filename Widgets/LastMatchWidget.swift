import WidgetKit
import SwiftUI
import SwiftData
import CribbageData
import CribbageBoardKit

/// Reads directly via `ModelContext`/`FetchDescriptor` rather than going through
/// `BoardHistoryStore` — that convenience wrapper is `@MainActor` (it exists so the app's
/// UI layer doesn't need to know about `BoardMatchRecord`/fetch descriptors at all), but a
/// widget's `TimelineProvider` isn't guaranteed to run on the main actor, and this is a
/// small enough fetch that duplicating it here is simpler than actor-hopping.
struct LastMatchEntry: TimelineEntry {
    let date: Date
    let match: BoardMatch?
}

struct LastMatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastMatchEntry {
        LastMatchEntry(date: .now, match: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (LastMatchEntry) -> Void) {
        completion(LastMatchEntry(date: .now, match: Self.fetchLastMatch()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastMatchEntry>) -> Void) {
        let entry = LastMatchEntry(date: .now, match: Self.fetchLastMatch())
        // Board matches don't change on their own -- this just gives WidgetKit a
        // reasonable refresh cadence in case a match was played since the last load.
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
        completion(timeline)
    }

    private static func fetchLastMatch() -> BoardMatch? {
        guard let container = try? CribbageDataStack.makeModelContainer(useAppGroup: true) else { return nil }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<BoardMatchRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.asBoardMatch
    }
}

struct LastMatchWidgetView: View {
    let entry: LastMatchEntry

    var body: some View {
        if let match = entry.match {
            VStack(alignment: .leading, spacing: 4) {
                Text("Last Match")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(scoreLine(for: match))
                    .font(.headline)
                    .lineLimit(2)
                if match.isComplete, let winnerIndex = match.winnerIndex {
                    Text("\(match.players[winnerIndex].name) won")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("In progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        } else {
            Text("No matches yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private func scoreLine(for match: BoardMatch) -> String {
        let one = match.players[0]
        let two = match.players[1]
        return "\(one.name) \(one.currentScore) – \(two.currentScore) \(two.name)"
    }
}

struct LastMatchWidget: Widget {
    let kind = "LastMatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastMatchProvider()) { entry in
            LastMatchWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Last Match")
        .description("Shows the score of your most recent physical board match.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct FifteenTwoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LastMatchWidget()
    }
}
