#if os(iOS) || os(macOS)
import SwiftUI
import CribbageKit
import CribbageVision

/// A rank+suit picker for one card — this is both the manual "tap to build your hand"
/// entry screen and the confirmation/correction UI for a scanned guess (see
/// docs/plan.md: the manual entry screen "doubles as the later Vision-correction
/// fallback"). `suggestedColor`, when set, dims the two suits that don't match the
/// detected color rather than hiding them outright — the color guess is a hint, not a
/// constraint, since it can be wrong.
struct CardPickerView: View {
    @Binding var rank: Rank?
    @Binding var suit: Suit?
    var suggestedColor: CardColor?

    private static let rankColumns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Self.rankColumns, spacing: 6) {
                ForEach(Rank.allCases, id: \.self) { candidate in
                    rankButton(for: candidate)
                }
            }

            HStack(spacing: 12) {
                ForEach(Suit.allCases, id: \.self) { candidate in
                    Button {
                        suit = candidate
                    } label: {
                        Text(candidate.symbol)
                            .font(.title)
                            .foregroundStyle(candidate.color)
                            .opacity(isDimmed(candidate) ? 0.35 : 1)
                    }
                    .buttonStyle(.bordered)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(suit == candidate ? Color.accentColor : .clear, lineWidth: 2)
                    )
                    .accessibilityLabel(candidate.spokenName)
                }
            }
        }
    }

    private func isDimmed(_ candidate: Suit) -> Bool {
        guard let suggestedColor else { return false }
        let candidateColor: CardColor = (candidate == .hearts || candidate == .diamonds) ? .red : .black
        return candidateColor != suggestedColor
    }

    @ViewBuilder
    private func rankButton(for candidate: Rank) -> some View {
        let tintColor: Color = rank == candidate ? .accentColor : .secondary
        Button(candidate.symbol) { rank = candidate }
            .buttonStyle(.bordered)
            .tint(tintColor)
    }
}
#endif
