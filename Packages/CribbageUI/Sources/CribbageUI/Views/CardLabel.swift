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

/// A plain, standard-components card label — "bare" on purpose per docs/plan.md
/// (Phase 3 build order): the visual polish pass with Liquid Glass comes in Phase 4.
struct CardLabel: View {
    let card: Card
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(card.rank.symbol)
                .font(.title3.bold())
            Text(card.suit.symbol)
                .font(.title3)
        }
        .foregroundStyle(card.suit.color)
        .frame(width: 44, height: 60)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: isSelected ? 3 : 1
                )
        )
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
