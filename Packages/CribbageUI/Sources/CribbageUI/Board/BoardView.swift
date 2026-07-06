#if !os(watchOS)
import SwiftUI
import SwiftData
import CribbageKit
import CribbageBoardKit
import CribbageData

/// The physical-board companion screen — see docs/plan.md: "a gorgeous, fast
/// scorekeeper... for people playing IRL." No cards, no hands, just two running scores,
/// quick-tap common point values, undo for mis-taps, and skunk detection.
public struct BoardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var controller: BoardSessionController?
    @State private var showingHistory = false
    @State private var showingNewMatchSheet = false

    public init() {}

    private static let quickPoints = [1, 2, 3, 4, 5, 6, 8, 12, 24]

    public var body: some View {
        NavigationStack {
            Group {
                if let controller {
                    BoardContentView(controller: controller, quickPoints: Self.quickPoints)
                } else {
                    ProgressView()
                }
            }
            .padding()
            .navigationTitle("Board")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("History") { showingHistory = true }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("New Match") { showingNewMatchSheet = true }
                }
            }
            .sheet(isPresented: $showingHistory) {
                if let controller {
                    BoardHistoryView(controller: controller)
                }
            }
            .sheet(isPresented: $showingNewMatchSheet) {
                NewMatchSheet { playerOne, playerTwo in
                    controller?.startNewMatch(playerOneName: playerOne, playerTwoName: playerTwo)
                }
            }
            .task {
                if controller == nil {
                    let store = BoardHistoryStore(modelContext: modelContext)
                    controller = BoardSessionController(store: store)
                }
            }
        }
    }
}

private struct BoardContentView: View {
    let controller: BoardSessionController
    let quickPoints: [Int]

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                PlayerPegPanel(controller: controller, playerIndex: 0, quickPoints: quickPoints)
                PlayerPegPanel(controller: controller, playerIndex: 1, quickPoints: quickPoints)
            }

            if controller.match.isComplete {
                VStack(spacing: 8) {
                    let winnerName = controller.match.players[controller.match.winnerIndex ?? 0].name
                    Text("\(winnerName) wins!")
                        .font(.title2.bold())
                    if let skunk = controller.skunkResult, skunk != .normal {
                        Text(skunk == .doubleSkunk ? "Double skunk!" : "Skunk!")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Spacer()
        }
    }
}

private struct PlayerPegPanel: View {
    let controller: BoardSessionController
    let playerIndex: Int
    let quickPoints: [Int]

    private var player: BoardPlayer { controller.match.players[playerIndex] }
    private let columns = [GridItem(.adaptive(minimum: 44))]

    var body: some View {
        VStack(spacing: 12) {
            Text(player.name).font(.headline)
            Text("\(player.currentScore)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .accessibilityLabel("\(player.name): \(player.currentScore) points")

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(quickPoints, id: \.self) { points in
                    Button("\(points)") {
                        controller.peg(playerIndex: playerIndex, points: points)
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.match.isComplete)
                    .accessibilityLabel("Add \(points) point\(points == 1 ? "" : "s") for \(player.name)")
                }
            }

            Button("Undo", systemImage: "arrow.uturn.backward") {
                controller.undoLastPeg(playerIndex: playerIndex)
            }
            .disabled(player.scoreHistory.isEmpty)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct NewMatchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playerOneName = "Player 1"
    @State private var playerTwoName = "Player 2"
    let onStart: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Player 1 name", text: $playerOneName)
                TextField("Player 2 name", text: $playerTwoName)
            }
            .navigationTitle("New Match")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onStart(playerOneName, playerTwoName)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    BoardView()
}
#endif
