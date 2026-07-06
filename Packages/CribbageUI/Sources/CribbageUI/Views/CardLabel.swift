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
        .accessibilityLabel("\(card.rank.spokenName) of \(card.suit.spokenName)")
    }
}

extension Rank {
    var spokenName: String {
        switch self {
        case .ace: "Ace"
        case .jack: "Jack"
        case .queen: "Queen"
        case .king: "King"
        default: "\(rawValue)"
        }
    }
}

extension Suit {
    var spokenName: String {
        switch self {
        case .clubs: "Clubs"
        case .diamonds: "Diamonds"
        case .hearts: "Hearts"
        case .spades: "Spades"
        }
    }
}
