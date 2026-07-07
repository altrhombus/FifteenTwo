#if os(iOS)
import SwiftUI
import CribbageKit

struct TurnBasedDiscardingView: View {
    let controller: TurnBasedMatchController
    let onSubmitted: () -> Void
    @State private var selected: [Card] = []
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose 2 cards to discard to the crib")
                .font(.headline)
            HStack(spacing: 8) {
                ForEach(controller.state.hands[controller.mySeat]) { card in
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
                    .disabled(isSubmitting)
                }
            }
            Button("Discard") {
                isSubmitting = true
                Task {
                    await controller.discard(selected)
                    onSubmitted()
                }
            }
            .disabled(selected.count != 2 || isSubmitting)
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

struct TurnBasedPeggingView: View {
    let controller: TurnBasedMatchController
    let onSubmitted: () -> Void
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 16) {
            if let starter = controller.state.starter {
                Label("Starter: \(starter.rank.symbol)\(starter.suit.symbol)", systemImage: "star.fill")
                    .font(.subheadline)
                    .accessibilityLabel("Starter: \(starter.spokenName)")
            }

            Text("Count: \(controller.state.peggingCount)")
                .font(.title2.monospacedDigit())

            HStack(spacing: 8) {
                ForEach(controller.state.peggingPile) { card in
                    CardLabel(card: card)
                }
            }
            .frame(minHeight: 60)

            let legalPlays = controller.legalMyPlays
            HStack(spacing: 8) {
                ForEach(controller.state.peggingRemaining[controller.mySeat]) { card in
                    Button {
                        isSubmitting = true
                        Task {
                            await controller.play(card)
                            onSubmitted()
                        }
                    } label: {
                        CardLabel(
                            card: card,
                            accessibilityState: legalPlays.contains(card) ? "playable" : "not currently playable"
                        )
                        .opacity(legalPlays.contains(card) ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting || !legalPlays.contains(card))
                }
            }

            if legalPlays.isEmpty {
                Text("No card you hold fits under 31 — say Go to pass.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Go") {
                    isSubmitting = true
                    Task {
                        await controller.sayGo()
                        onSubmitted()
                    }
                }
                .disabled(isSubmitting)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct TurnBasedHandSummaryView: View {
    let controller: TurnBasedMatchController
    let onSubmitted: () -> Void
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 16) {
            if controller.state.phase == .gameOver {
                let youWon = controller.state.winner == controller.mySeat
                Text(youWon ? "You win!" : "Your opponent wins")
                    .font(.largeTitle.bold())
                if let skunk = controller.state.skunkResult, skunk != .normal {
                    Text(skunk == .doubleSkunk ? "Double skunk!" : "Skunk!")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
            } else if let summary = controller.state.lastRoundSummary {
                Text("Hand Summary").font(.headline)
                Text("Non-dealer's hand: \(summary.nonDealerHand.total) pts")
                if let dealerHand = summary.dealerHand {
                    Text("Dealer's hand: \(dealerHand.total) pts")
                }
                if let crib = summary.crib {
                    Text("Crib: \(crib.total) pts")
                }
                Button("Deal Next Hand") {
                    isSubmitting = true
                    Task {
                        await controller.dealIfMyTurn()
                        onSubmitted()
                    }
                }
                .disabled(isSubmitting)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
#endif
