#if !os(watchOS)
import SwiftUI
import CribbageKit

extension Rank {
    var symbol: String {
        switch self {
        case .ace: "A"
        case .jack: "J"
        case .queen: "Q"
        case .king: "K"
        default: "\(rawValue)"
        }
    }
}

extension Suit {
    var symbol: String {
        switch self {
        case .clubs: "♣"
        case .diamonds: "♦"
        case .hearts: "♥"
        case .spades: "♠"
        }
    }

    var color: Color {
        switch self {
        case .hearts, .diamonds: .red
        case .clubs, .spades: .primary
        }
    }
}

/// A card face styled like a real playing card (corner pip + large center suit) rather
/// than a plain rounded rectangle of text — the Phase 4 visual polish pass. Cards are
/// content, not chrome, so per docs/plan.md's Design Language section they stay opaque
/// on the base layer rather than sitting under Liquid Glass, which is reserved for the
/// floating HUD around them (see ScoreHeader).
struct CardLabel: View {
    let card: Card
    var isSelected: Bool = false
    /// State description read after the card's name — e.g. "selected for discard",
    /// "played, count is 23", "not currently playable" — see docs/plan.md
    /// ("Accessibility"): "every card is a distinct accessibility element with real
    /// state," not just a name.
    var accessibilityState: String?

    private var cornerPip: some View {
        VStack(spacing: 0) {
            Text(card.rank.symbol).font(.system(size: 15, weight: .bold))
            Text(card.suit.symbol).font(.system(size: 11))
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.background)

            cornerPip
                .padding(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 0))

            cornerPip
                .rotationEffect(.degrees(180))
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 4))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            Text(card.suit.symbol)
                .font(.system(size: 22))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(card.suit.color)
        .frame(width: 48, height: 66) // ~2.5:3.5, the standard playing-card aspect ratio
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.3),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.spokenName)
        .accessibilityValue(accessibilityState ?? "")
    }
}
#endif
