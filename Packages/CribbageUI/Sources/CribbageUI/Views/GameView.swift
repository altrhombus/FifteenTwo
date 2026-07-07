#if !os(watchOS)
import SwiftUI
import CribbageKit

/// Built on standard SwiftUI system components (Phase 3), with the Phase 4 visual polish
/// pass layering Liquid Glass onto the floating chrome — the score HUD — per docs/plan.md's
/// Design Language section: glass belongs on the navigation/chrome layer, while the cards
/// and board stay opaque on the base layer for legibility.
public struct GameView: View {
    @State private var controller: GameSessionController
    let settings: SettingsStore

    public init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        _controller = State(wrappedValue: GameSessionController(ruleset: settings.ruleset))
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
                    DiscardingView(controller: controller, beginnerModeEnabled: settings.beginnerModeEnabled)
                case .cutStarter:
                    CutStarterView(controller: controller)
                case .pegging:
                    PeggingView(controller: controller, beginnerModeEnabled: settings.beginnerModeEnabled)
                case .counting:
                    CountingView(controller: controller, beginnerModeEnabled: settings.beginnerModeEnabled)
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
            .onChange(of: settings.ruleset) { _, newValue in
                controller.ruleset = newValue
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
    let beginnerModeEnabled: Bool
    // An ordered array, not a Set: tapping a third card while 2 are already selected
    // swaps out the oldest one, so every tap always visibly does something rather than
    // silently no-op'ing — see the "unpick cards" confusion this fixed.
    @State private var selected: [Card] = []
    @Namespace private var rotorNamespace

    private var isDealer: Bool { controller.state.dealer == controller.humanSeat }

    private var tip: String {
        let cribAdvice = isDealer
            ? "Since you're the dealer, cards that help your own crib are extra valuable."
            : "Since the CPU is dealing, avoid giving away strong crib cards like 5s and pairs."
        return "Tip: Look for pairs and cards that add up to 15 — they score points in your hand. \(cribAdvice)"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose 2 cards to discard to the crib")
                .font(.headline)
            Text("Tap a card to select it, tap it again to change your mind.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if beginnerModeEnabled {
                Label(tip, systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal)
            }
            HStack(spacing: 8) {
                ForEach(controller.state.hands[controller.humanSeat]) { card in
                    Button {
                        toggle(card)
                    } label: {
                        CardLabel(
                            card: card,
                            isSelected: selected.contains(card),
                            accessibilityState: selected.contains(card) ? "selected for discard" : nil
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityRotorEntry(id: card.id, in: rotorNamespace)
                }
            }
            .accessibilityRotor("Hand") {
                ForEach(controller.state.hands[controller.humanSeat]) { card in
                    AccessibilityRotorEntry(Text(card.spokenName), id: card.id, in: rotorNamespace)
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
    let beginnerModeEnabled: Bool
    @Namespace private var pileRotorNamespace
    @Namespace private var handRotorNamespace

    private var isHumanTurn: Bool { controller.state.turnToAct == controller.humanSeat }

    var body: some View {
        VStack(spacing: 16) {
            if let starter = controller.state.starter {
                Label("Starter: \(starter.rank.symbol)\(starter.suit.symbol)", systemImage: "star.fill")
                    .font(.subheadline)
                    .accessibilityLabel("Starter: \(starter.spokenName)")
            }

            Text("Count: \(controller.state.peggingCount)")
                .font(.title2.monospacedDigit())

            if beginnerModeEnabled {
                Label(
                    "Tip: Playing a card that makes the count 15 or exactly 31 scores points. " +
                        "Matching the rank or continuing a run also scores.",
                    systemImage: "lightbulb.fill"
                )
                .font(.caption)
                .foregroundStyle(.blue)
                .multilineTextAlignment(.leading)
                .padding(.horizontal)
            }

            HStack(spacing: 8) {
                ForEach(Array(controller.state.peggingPile.enumerated()), id: \.element.id) { index, card in
                    CardLabel(card: card, accessibilityState: "played, position \(index + 1)")
                        .accessibilityRotorEntry(id: card.id, in: pileRotorNamespace)
                }
            }
            .frame(minHeight: 60)
            .accessibilityRotor("Pegging Events") {
                ForEach(controller.state.peggingPile) { card in
                    AccessibilityRotorEntry(Text(card.spokenName), id: card.id, in: pileRotorNamespace)
                }
            }

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
                        CardLabel(
                            card: card,
                            accessibilityState: legalPlays.contains(card) ? "playable" : "not currently playable"
                        )
                        .opacity(legalPlays.contains(card) ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isHumanTurn || !legalPlays.contains(card))
                    .accessibilityRotorEntry(id: card.id, in: handRotorNamespace)
                }
            }
            .accessibilityRotor("Hand") {
                ForEach(controller.state.peggingRemaining[controller.humanSeat]) { card in
                    AccessibilityRotorEntry(Text(card.spokenName), id: card.id, in: handRotorNamespace)
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
    let beginnerModeEnabled: Bool

    var body: some View {
        // Muggins makes the show interactive — while a count is pending, the itemized
        // summary is withheld (it would give away the answer) and the player counts instead.
        if controller.state.pendingCount != nil {
            MugginsCountingView(controller: controller)
        } else if let summary = controller.state.lastRoundSummary {
            VStack(alignment: .leading, spacing: 12) {
                Text("Hand Summary").font(.headline)
                if beginnerModeEnabled {
                    let nonDealerPegging = summary.nonDealerPegging
                    // His heels is a dealer point taken at the cut — group it with the
                    // dealer's pegging so every play-phase point is accounted for.
                    let dealerPegging = (summary.hisHeels.map { [$0] } ?? []) + summary.dealerPegging
                    if !nonDealerPegging.isEmpty {
                        ItemizedScoreView(title: "Non-dealer's pegging", events: nonDealerPegging)
                    }
                    if !dealerPegging.isEmpty {
                        ItemizedScoreView(title: "Dealer's pegging", events: dealerPegging)
                    }
                    ItemizedScoreView(title: "Non-dealer's hand", breakdown: summary.nonDealerHand)
                    if let dealerHand = summary.dealerHand {
                        ItemizedScoreView(title: "Dealer's hand", breakdown: dealerHand)
                    }
                    if let crib = summary.crib {
                        ItemizedScoreView(title: "Crib", breakdown: crib)
                    }
                } else {
                    Text("Non-dealer's hand: \(summary.nonDealerHand.total) pts")
                    if let dealerHand = summary.dealerHand {
                        Text("Dealer's hand: \(dealerHand.total) pts")
                    }
                    if let crib = summary.crib {
                        Text("Crib: \(crib.total) pts")
                    }
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

/// The interactive muggins show: the player counts the item they own, and the game pegs
/// any points they miss for the opponent. In solo play the CPU counts perfectly, so the
/// player only ever sees the "claim your count" step (and gets mugginsed if they under-count).
private struct MugginsCountingView: View {
    let controller: GameSessionController

    var body: some View {
        if let pending = controller.humanPendingCount {
            MugginsCountingContent(
                pending: pending,
                itemCards: cardsForCountingItem(pending.item, in: controller.state),
                starter: controller.state.starter,
                onClaim: { controller.claimScore($0) },
                onMuggins: { controller.callMuggins() },
                onPass: { controller.passMuggins() }
            )
        } else {
            // Transient — the CPU counts instantly, so this rarely renders.
            Label("Opponent is counting…", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        }
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
#endif
