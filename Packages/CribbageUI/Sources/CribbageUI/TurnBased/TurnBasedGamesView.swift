#if os(iOS)
import SwiftUI
import CribbageKit
@preconcurrency import GameKit

/// "Play a friend over days, not live" — see docs/plan.md's Game Center section. A list
/// of the local player's turn-based matches (refreshed via `TurnBasedMatchListController`'s
/// `GKLocalPlayerListener`), a "New Game" entry point into the system matchmaker, and a
/// per-match screen for taking your turn.
public struct TurnBasedGamesView: View {
    @State private var listController = TurnBasedMatchListController()
    @State private var showingMatchmaker = false
    @State private var selectedMatch: GKTurnBasedMatch?
    @State private var showingGame = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if listController.matches.isEmpty {
                    emptyState
                } else {
                    List(listController.matches, id: \.matchID) { match in
                        Button {
                            selectedMatch = match
                            showingGame = true
                        } label: {
                            TurnBasedMatchRow(match: match)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Turn-Based")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Game", systemImage: "plus") { showingMatchmaker = true }
                }
            }
            .task { await listController.refresh() }
            .onDisappear { listController.stopListening() }
        }
        .sheet(isPresented: $showingMatchmaker) {
            TurnBasedMatchmakerView {
                showingMatchmaker = false
                Task { await listController.refresh() }
            }
        }
        .sheet(
            isPresented: $showingGame,
            onDismiss: { Task { await listController.refresh() } },
            content: {
                if let selectedMatch {
                    TurnBasedGameScreen(match: selectedMatch)
                }
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("No Turn-Based Games").font(.headline)
            Text("Start a game to play cribbage with a friend, one turn at a time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct TurnBasedMatchRow: View {
    let match: GKTurnBasedMatch

    private var opponentName: String {
        let opponent = match.participants.first { $0.player?.gamePlayerID != GKLocalPlayer.local.gamePlayerID }
        return opponent?.player?.displayName ?? "Waiting for opponent"
    }

    private var isMyTurn: Bool {
        match.currentParticipant?.player?.gamePlayerID == GKLocalPlayer.local.gamePlayerID
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(opponentName).font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(isMyTurn ? Color.accentColor : .secondary)
            }
            Spacer()
            if isMyTurn {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8)
            }
        }
    }

    private var statusText: String {
        if match.status == .ended { return "Finished" }
        return isMyTurn ? "Your turn" : "Waiting"
    }
}

private struct TurnBasedGameScreen: View {
    let match: GKTurnBasedMatch
    @State private var controller: TurnBasedMatchController?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let controller {
                    TurnBasedPlayView(controller: controller, onTurnSubmitted: { dismiss() })
                } else if isLoading {
                    ProgressView()
                } else {
                    Text("Couldn't load this match.").foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Cribbage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            controller = try? await TurnBasedMatchController.load(match)
            isLoading = false
        }
    }
}

private struct TurnBasedPlayView: View {
    let controller: TurnBasedMatchController
    let onTurnSubmitted: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            scoreHeader
            Divider()

            if !controller.isMyTurn {
                Text("Waiting for your opponent…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                phaseView
            }

            if let errorMessage = controller.errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var phaseView: some View {
        switch controller.state.phase {
        case .dealing:
            ProgressView()
                .task {
                    await controller.dealIfMyTurn()
                    onTurnSubmitted()
                }
        case .discarding:
            TurnBasedDiscardingView(controller: controller, onSubmitted: onTurnSubmitted)
        case .cutStarter:
            Button("Cut for Starter") {
                Task {
                    await controller.cutForStarterIfMyTurn()
                    onTurnSubmitted()
                }
            }
            .buttonStyle(.borderedProminent)
        case .pegging:
            TurnBasedPeggingView(controller: controller, onSubmitted: onTurnSubmitted)
        case .counting, .gameOver:
            TurnBasedHandSummaryView(controller: controller, onSubmitted: onTurnSubmitted)
        }
    }

    private var scoreHeader: some View {
        HStack {
            scoreColumn(title: "You", score: controller.state.scores[controller.mySeat])
            Spacer()
            scoreColumn(title: "Opponent", score: controller.state.scores[controller.opponentSeat])
        }
    }

    private func scoreColumn(title: String, score: Int) -> some View {
        VStack {
            Text(title).font(.headline)
            Text("\(score)").font(.largeTitle.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TurnBasedGamesView()
}
#endif
