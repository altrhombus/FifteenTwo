#if !os(watchOS)
import SwiftUI
import CribbageBoardKit

struct BoardHistoryView: View {
    let controller: BoardSessionController
    @State private var matches: [BoardMatch] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if matches.isEmpty {
                    Text("No matches yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(matches) { match in
                    row(for: match)
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Match History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { matches = controller.fetchHistory() }
        }
    }

    private func row(for match: BoardMatch) -> some View {
        let playerOne = match.players[0]
        let playerTwo = match.players[1]
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(playerOne.name) \(playerOne.currentScore) – \(playerTwo.currentScore) \(playerTwo.name)")
                    .font(.subheadline)
                Spacer()
                if !match.isComplete {
                    Text("In progress").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(match.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            controller.delete(matches[index])
        }
        matches.remove(atOffsets: offsets)
    }
}
#endif
