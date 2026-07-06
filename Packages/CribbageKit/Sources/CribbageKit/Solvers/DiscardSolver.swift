/// Exact discard expected-value analysis — see docs/plan.md ("Discard solver — confirmed
/// exact and real-time, not aspirational"). Choosing 2 discards from 6 is `C(6,2) = 15`
/// candidates; hand EV averages over the 46 unseen cards, crib EV additionally averages
/// over the opponent's unknown 2-card contribution from the remaining 45
/// (`C(45,2) = 990`) — about 684,000 `Scorer` calls total, comfortably real-time.
public enum DiscardSolver {
    public static func bestDiscards(hand: [Card], isDealer: Bool, ruleset: Ruleset = .standard) -> [DiscardOption] {
        precondition(hand.count == 6, "Discard analysis requires a 6-card dealt hand, got \(hand.count)")

        let unseen = Deck.standard52.filter { !hand.contains($0) }
        precondition(unseen.count == 46, "Expected 46 unseen cards, got \(unseen.count)")

        // The 45-card "remaining after the starter" pool always has the same size, so its
        // C(45,2) index-pairs are precomputed once and reused across all 46 starters.
        let opponentDiscardIndexPairs = combinationIndices(45, choose: 2)

        var options: [DiscardOption] = []
        for discardIndices in combinationIndices(6, choose: 2) {
            let discarded = discardIndices.map { hand[$0] }
            let kept = hand.enumerated().filter { !discardIndices.contains($0.offset) }.map(\.element)

            var handTotal = 0
            var cribTotal = 0
            var cribCount = 0

            for (starterIndex, starter) in unseen.enumerated() {
                handTotal += Scorer.score(hand: kept, starter: starter, isCrib: false, ruleset: ruleset).total

                var remaining = unseen
                remaining.remove(at: starterIndex)
                for pair in opponentDiscardIndexPairs {
                    let opponentDiscard = pair.map { remaining[$0] }
                    let crib = discarded + opponentDiscard
                    cribTotal += Scorer.score(hand: crib, starter: starter, isCrib: true, ruleset: ruleset).total
                    cribCount += 1
                }
            }

            let handEV = Double(handTotal) / Double(unseen.count)
            let cribEV = Double(cribTotal) / Double(cribCount)
            let net = isDealer ? handEV + cribEV : handEV - cribEV

            options.append(DiscardOption(
                kept: kept,
                discarded: discarded,
                expectedHandValue: handEV,
                expectedCribValue: cribEV,
                netExpectedValue: net
            ))
        }
        return options.sorted { $0.netExpectedValue > $1.netExpectedValue }
    }
}
