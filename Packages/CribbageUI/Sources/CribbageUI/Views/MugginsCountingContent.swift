#if !os(watchOS)
import SwiftUI
import CribbageKit

/// The cards that make up a counting item, for display during the muggins show. Both hands
/// are face-up at the show, so revealing the opponent's item when you're deciding whether to
/// muggins it is correct.
func cardsForCountingItem(_ item: CountingItem, in state: GameState) -> [Card] {
    switch item {
    case .nonDealerHand: return state.hands[state.dealer.opponent]
    case .dealerHand: return state.hands[state.dealer]
    case .crib: return state.crib
    }
}

/// Shared muggins-show UI, reused by the solo, multiplayer, and turn-based counting views so
/// the interaction is identical everywhere. The owning controller supplies the current
/// `pending` decision, the cards to show, and the three action callbacks.
struct MugginsCountingContent: View {
    let pending: PendingCount
    let itemCards: [Card]
    let starter: Card?
    let onClaim: (Int) -> Void
    let onMuggins: () -> Void
    let onPass: () -> Void

    @State private var claim = 0

    private var itemNoun: String { pending.item == .crib ? "crib" : "hand" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Counting — Muggins").font(.headline)

            HStack(spacing: 8) {
                ForEach(itemCards) { CardLabel(card: $0) }
                if let starter {
                    Divider().frame(height: 66)
                    VStack(spacing: 2) {
                        Text("Starter").font(.caption2).foregroundStyle(.secondary)
                        CardLabel(card: starter)
                    }
                }
            }

            switch pending.stage {
            case .awaitingClaim:
                Text("Count your \(itemNoun) (with the starter). How many points?")
                    .font(.subheadline)
                Stepper("Your count: \(claim)", value: $claim, in: 0...29)
                    .fixedSize()
                Button("Claim \(claim)") {
                    onClaim(claim)
                    claim = 0
                }
                .buttonStyle(.borderedProminent)
                Text("Miss any and your opponent can muggins them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            case .awaitingMuggins:
                Text("Your opponent counted their \(itemNoun). Spot points they missed?")
                    .font(.subheadline)
                HStack {
                    Button("Muggins!") { onMuggins() }
                        .buttonStyle(.borderedProminent)
                    Button("Pass") { onPass() }
                }
            }
        }
    }
}
#endif
