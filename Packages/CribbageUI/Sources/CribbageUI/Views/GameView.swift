import SwiftUI
import CribbageKit

/// Built on standard SwiftUI system components (Phase 3), with the Phase 4 visual polish
/// pass layering Liquid Glass onto the floating chrome — the score HUD — per docs/plan.md's
/// Design Language section: glass belongs on the navigation/chrome layer, while the cards
/// and board stay opaque on the base layer for legibility.
public struct GameView: View {
    @State private var controller: GameSessionController

    public init(controller: GameSessionController = GameSessionController()) {
        _controller = State(wrappedValue: controller)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScoreHeader(controller: controller)
                Divider()

                switch controller.state.phase {
                case .dealing:
                    ProgressView()
                case .discarding:
                    DiscardingView(controller: controller)
                case .cutStarter:
                    CutStarterView(controller: controller)
                case .pegging:
                    PeggingView(controller: controller)
                case .counting:
                    CountingView(controller: controller)
                case .gameOver:
                    GameOverView(controller: controller)
                }

                if controller.isCPUThinking {
                    Label("CPU is thinking…", systemImage: "brain")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Fifteen Two")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("Difficulty", selection: Bindable(controller).difficulty) {
                        ForEach(CPUDifficulty.allCases) { difficulty in
                            Text(difficulty.rawValue.capitalized).tag(difficulty)
                        }
                    }
                }
            }
            .task {
                if controller.state.phase == .dealing {
                    controller.startGame()
                }
            }
        }
    }
}

private struct ScoreHeader: View {
    let controller: GameSessionController

    var body: some View {
        HStack {
            scoreColumn(
                title: "You",
                score: controller.state.scores[controller.humanSeat],
                isDealer: controller.state.dealer == controller.humanSeat
            )
            Spacer()
            scoreColumn(
                title: "CPU",
                score: controller.state.scores[controller.cpuSeat],
                isDealer: controller.state.dealer == controller.cpuSeat
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func scoreColumn(title: String, score: Int, isDealer: Bool) -> some View {
        VStack {
            Text(title).font(.headline)
            Text("\(score)").font(.largeTitle.monospacedDigit())
            if isDealer {
                Text("Dealer").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DiscardingView: View {
    let controller: GameSessionController
    // An ordered array, not a Set: tapping a third card while 2 are already selected
    // swaps out the oldest one, so every tap always visibly does something rather than
    // silently no-op'ing — see the "unpick cards" confusion this fixed.
    @State private var selected: [Card] = []

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose 2 cards to discard to the crib")
                .font(.headline)
            Text("Tap a card to select it, tap it again to change your mind.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(controller.state.hands[controller.humanSeat]) { card in
                    Button {
                        toggle(card)
                    } label: {
                        CardLabel(card: card, isSelected: selected.contains(card))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Discard") {
                controller.discard(selected)
                selected = []
            }
            .disabled(selected.count != 2)
            .buttonStyle(.borderedProminent)
        }
    }

    private func toggle(_ card: Card) {
        if let index = selected.firstIndex(of: card) {
            selected.remove(at: index)
            return
        }
        selected.append(card)
        if selected.count > 2 {
            selected.removeFirst()
        }
    }
}

private struct CutStarterView: View {
    let controller: GameSessionController

    var body: some View {
        VStack(spacing: 16) {
            Text("Both hands are set. Cut for the starter card.")
                .font(.headline)
            Button("Cut for Starter") {
                controller.cutForStarter()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct PeggingView: View {
    let controller: GameSessionController

    private var isHumanTurn: Bool { controller.state.turnToAct == controller.humanSeat }

    var body: some View {
        VStack(spacing: 16) {
            if let starter = controller.state.starter {
                Label("Starter: \(starter.rank.symbol)\(starter.suit.symbol)", systemImage: "star.fill")
                    .font(.subheadline)
            }

            Text("Count: \(controller.state.peggingCount)")
                .font(.title2.monospacedDigit())

            HStack(spacing: 8) {
                ForEach(controller.state.peggingPile) { card in
                    CardLabel(card: card)
                }
            }
            .frame(minHeight: 60)

            Text("CPU has \(controller.state.peggingRemaining[controller.cpuSeat].count) card(s) left")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text(isHumanTurn ? "Your turn" : "Waiting for CPU…")
                .font(.headline)

            let legalPlays = controller.legalHumanPlays
            HStack(spacing: 8) {
                ForEach(controller.state.peggingRemaining[controller.humanSeat]) { card in
                    Button {
                        controller.play(card)
                    } label: {
                        CardLabel(card: card)
                            .opacity(legalPlays.contains(card) ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isHumanTurn || !legalPlays.contains(card))
                }
            }

            if isHumanTurn && legalPlays.isEmpty {
                Text("No card you hold fits under 31 — say Go to pass.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Go") {
                    controller.sayGo()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct CountingView: View {
    let controller: GameSessionController

    var body: some View {
        if let summary = controller.state.lastRoundSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hand Summary").font(.headline)
                Text("Non-dealer's hand: \(summary.nonDealerHand.total) pts")
                if let dealerHand = summary.dealerHand {
                    Text("Dealer's hand: \(dealerHand.total) pts")
                }
                if let crib = summary.crib {
                    Text("Crib: \(crib.total) pts")
                }

                if let analysis = controller.lastDiscardAnalysis {
                    Divider()
                    DiscardAnalysisView(analysis: analysis)
                }

                Divider()
                ReplayTransparencyView(seed: summary.seed) {
                    controller.practiceThisHandAgain()
                }

                Button("Deal Next Hand") {
                    controller.dealNextHand()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Solo play has no adversary, so this is framed as transparency/replay, not a fairness
/// *proof* — see docs/plan.md ("RNG & Fairness"): the same seed-reveal mechanism means
/// something stronger once Multipeer exists (Phase 10), where the copy changes to match.
private struct ReplayTransparencyView: View {
    let seed: Seed256
    let onPracticeAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Replay & Transparency").font(.headline)
            Text("This hand's deal was determined by a seed generated before dealing:")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(seed.hexString.prefix(16) + "…")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Button("Practice This Hand Again") {
                onPracticeAgain()
            }
            .buttonStyle(.bordered)
        }
    }
}

/// The post-hand training breakdown: how the human's discard compares to every option
/// `DiscardSolver` considered — see docs/plan.md ("post-game breakdown showing expected
/// value of every discard choice you could've made").
private struct DiscardAnalysisView: View {
    let analysis: DiscardAnalysis

    var body: some View {
        if let chosen = analysis.chosenOption, let best = analysis.bestOption {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Discard").font(.headline)
                row(label: "You discarded", option: chosen)

                if Set(chosen.discarded) == Set(best.discarded) {
                    Text("That was the best possible discard!")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    row(label: "Best discard", option: best)
                    let delta = best.netExpectedValue - chosen.netExpectedValue
                    Text("You left \(delta, specifier: "%.1f") expected points on the table.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func row(label: String, option: DiscardOption) -> some View {
        HStack {
            Text("\(label): \(option.discarded.map { "\($0.rank.symbol)\($0.suit.symbol)" }.joined(separator: " "))")
            Spacer()
            Text("\(option.netExpectedValue, specifier: "%.1f") pts")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

private struct GameOverView: View {
    let controller: GameSessionController

    var body: some View {
        VStack(spacing: 16) {
            let youWon = controller.state.winner == controller.humanSeat
            Text(youWon ? "You win!" : "CPU wins")
                .font(.largeTitle.bold())
            if let skunk = controller.state.skunkResult, skunk != .normal {
                Text(skunk == .doubleSkunk ? "Double skunk!" : "Skunk!")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            if let summary = controller.state.lastRoundSummary {
                Divider()
                ReplayTransparencyView(seed: summary.seed) {
                    controller.practiceThisHandAgain()
                }
            }

            Button("New Game") {
                controller.newGame()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    GameView()
}
