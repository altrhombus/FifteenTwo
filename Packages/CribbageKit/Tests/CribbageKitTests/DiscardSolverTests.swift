import Testing
@testable import CribbageKit

struct DiscardSolverTests {
    private let sampleHand = [
        Card(rank: .five, suit: .spades), Card(rank: .six, suit: .clubs),
        Card(rank: .seven, suit: .diamonds), Card(rank: .king, suit: .hearts),
        Card(rank: .two, suit: .clubs), Card(rank: .nine, suit: .spades)
    ]

    @Test func returnsAllFifteenDiscardCombinationsExactlyOnce() {
        let options = DiscardSolver.bestDiscards(hand: sampleHand, isDealer: true)
        #expect(options.count == 15)

        for option in options {
            #expect(option.kept.count == 4)
            #expect(option.discarded.count == 2)
            #expect(Set(option.kept + option.discarded) == Set(sampleHand))
        }

        let discardPairs = Set(options.map { Set($0.discarded) })
        #expect(discardPairs.count == 15) // no duplicate candidate appears twice
    }

    @Test func isSortedBestFirst() {
        let options = DiscardSolver.bestDiscards(hand: sampleHand, isDealer: false)
        for (first, second) in zip(options, options.dropFirst()) {
            #expect(first.netExpectedValue >= second.netExpectedValue)
        }
    }

    @Test func dealerNetValueAddsCribDealerNetValueSubtractsCrib() {
        let asDealer = DiscardSolver.bestDiscards(hand: sampleHand, isDealer: true)
        let asNonDealer = DiscardSolver.bestDiscards(hand: sampleHand, isDealer: false)

        let dealerByDiscard = Dictionary(uniqueKeysWithValues: asDealer.map { (Set($0.discarded), $0) })
        for option in asNonDealer {
            guard let dealerVersion = dealerByDiscard[Set(option.discarded)] else {
                Issue.record("Missing matching discard option")
                continue
            }
            #expect(abs(dealerVersion.expectedHandValue - option.expectedHandValue) < 0.0001)
            #expect(abs(dealerVersion.expectedCribValue - option.expectedCribValue) < 0.0001)
            let expectedDealerNet = option.expectedHandValue + option.expectedCribValue
            #expect(abs(dealerVersion.netExpectedValue - expectedDealerNet) < 0.0001)
            #expect(abs(option.netExpectedValue - (option.expectedHandValue - option.expectedCribValue)) < 0.0001)
        }
    }

    /// Independently re-derives the hand EV and crib EV for a single candidate using a
    /// separate, straightforward enumeration (not DiscardSolver's implementation) and
    /// checks the solver agrees — see docs/plan.md ("no guessing"): this validates the
    /// solver's bookkeeping (which cards are excluded, how the average is computed)
    /// against an independent re-derivation, rather than a memorized expected number.
    @Test func handAndCribExpectedValuesMatchAnIndependentReDerivation() {
        let hand = sampleHand
        let discarded = [Card(rank: .two, suit: .clubs), Card(rank: .nine, suit: .spades)]
        let kept = hand.filter { !discarded.contains($0) }

        let unseen = Deck.standard52.filter { !hand.contains($0) }
        #expect(unseen.count == 46)

        var handTotal = 0
        var cribTotal = 0
        var cribCount = 0
        for (starterIndex, starter) in unseen.enumerated() {
            handTotal += Scorer.score(hand: kept, starter: starter, isCrib: false).total

            var remaining = unseen
            remaining.remove(at: starterIndex)
            for otherIndex in 0..<remaining.count {
                for secondIndex in (otherIndex + 1)..<remaining.count {
                    let crib = discarded + [remaining[otherIndex], remaining[secondIndex]]
                    cribTotal += Scorer.score(hand: crib, starter: starter, isCrib: true).total
                    cribCount += 1
                }
            }
        }
        let expectedHandEV = Double(handTotal) / Double(unseen.count)
        let expectedCribEV = Double(cribTotal) / Double(cribCount)

        let options = DiscardSolver.bestDiscards(hand: hand, isDealer: true)
        guard let match = options.first(where: { Set($0.discarded) == Set(discarded) }) else {
            Issue.record("Could not find the candidate discard in the solver's output")
            return
        }

        #expect(abs(match.expectedHandValue - expectedHandEV) < 0.0001)
        #expect(abs(match.expectedCribValue - expectedCribEV) < 0.0001)
    }

    @Test func preferringARunAndFifteensOverIsolatedCardsRanksHigher() {
        // 3,4,5,6 forms a run of four plus fifteen potential; 10,K are isolated high
        // cards with little combinatorial upside. Keeping the run should out-rank
        // keeping the two high cards, regardless of the precise EV numbers.
        let hand = [
            Card(rank: .three, suit: .spades), Card(rank: .four, suit: .clubs),
            Card(rank: .five, suit: .diamonds), Card(rank: .six, suit: .hearts),
            Card(rank: .ten, suit: .spades), Card(rank: .king, suit: .clubs)
        ]
        let options = DiscardSolver.bestDiscards(hand: hand, isDealer: false)
        let best = options[0]
        #expect(Set(best.discarded) == Set([Card(rank: .ten, suit: .spades), Card(rank: .king, suit: .clubs)]))
    }
}
