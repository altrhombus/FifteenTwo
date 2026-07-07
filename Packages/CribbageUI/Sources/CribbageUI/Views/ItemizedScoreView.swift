#if !os(watchOS)
import SwiftUI
import CribbageKit

/// Beginner Mode's itemized scoring breakdown — see docs/plan.md's framing on "really
/// leaning into the training portion": `ScoreBreakdown` already computes every individual
/// scoring event, this is the first place anything actually displays them instead of just
/// the total.
struct ItemizedScoreView: View {
    let title: String
    let breakdown: ScoreBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(title): \(breakdown.total) pts").font(.subheadline.bold())
            ForEach(Array(breakdown.allEvents.enumerated()), id: \.offset) { _, event in
                Text("• \(describe(event))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func describe(_ event: ScoreEvent) -> String {
        let cardsText = event.cards.map { "\($0.rank.symbol)\($0.suit.symbol)" }.joined(separator: " ")
        switch event.kind {
        case .fifteen: return "\(cardsText) = 15 for \(event.points)"
        case .pair: return "\(cardsText) = pair for \(event.points)"
        case .run: return "\(cardsText) = run of \(event.cards.count) for \(event.points)"
        case .flush: return "\(event.cards.count)-card flush for \(event.points)"
        case .nobs: return "\(cardsText) = his nobs for \(event.points)"
        case .thirtyOne, .go, .hisHeels: return "\(cardsText) for \(event.points)"
        }
    }
}
#endif
