import Testing
@testable import CribbageKit

/// Every expected total below is derived by hand from the official scoring rules
/// (enumerating every subset for fifteens/pairs/runs), not recalled from memory —
/// see docs/plan.md ("Rules accuracy is non-negotiable — no guessing").
struct ScorerTests {
    // MARK: - The canonical 29-point maximum hand
    // Hand: 5♠ 5♣ 5♦ J♥, starter 5♥ (the fourth 5, matching the jack's suit).
    // Fifteens: four (5+10) pairs-with-the-jack + four (5+5+5) triples = 8 combos = 16 pts.
    // Pairs: four 5s -> C(4,2) = 6 pairs = 12 pts.
    // Runs: ranks {5, jack} aren't consecutive -> 0.
    // Flush: hand suits are mixed (spades/clubs/diamonds/hearts) -> 0.
    // Nobs: J♥ is in the hand and starter is 5♥ -> 1 pt.
    // Total: 16 + 12 + 0 + 0 + 1 = 29.
    @Test func maximumTwentyNineHand() {
        let hand = [
            Card(rank: .five, suit: .spades),
            Card(rank: .five, suit: .clubs),
            Card(rank: .five, suit: .diamonds),
            Card(rank: .jack, suit: .hearts)
        ]
        let starter = Card(rank: .five, suit: .hearts)

        let breakdown = Scorer.score(hand: hand, starter: starter, isCrib: false)

        #expect(breakdown.fifteens.reduce(0) { $0 + $1.points } == 16)
        #expect(breakdown.pairs.reduce(0) { $0 + $1.points } == 12)
        #expect(breakdown.runs.isEmpty)
        #expect(breakdown.flush.isEmpty)
        #expect(breakdown.nobs.reduce(0) { $0 + $1.points } == 1)
        #expect(breakdown.total == 29)
    }

    // MARK: - A verified zero-point ("fish") hand
    // Hand: K♠ 2♣ 4♦ 6♥, starter J♠ (mixed suits, no jack in hand, no pairs).
    // Pip values {10, 2, 4, 6, 10}: every subset of size 2-5 was checked by hand and none
    // sums to 15. Ranks {2, 4, 6, 11(J), 13(K)} contain no 3 consecutive values.
    @Test func zeroPointHand() {
        let hand = [
            Card(rank: .king, suit: .spades),
            Card(rank: .two, suit: .clubs),
            Card(rank: .four, suit: .diamonds),
            Card(rank: .six, suit: .hearts)
        ]
        let starter = Card(rank: .jack, suit: .spades)

        let breakdown = Scorer.score(hand: hand, starter: starter, isCrib: false)

        #expect(breakdown.total == 0)
    }

    // MARK: - A "double run" exercising runs-with-a-pair together with fifteens
    // Hand: 3♠ 3♣ 4♦ 5♥, starter 6♠.
    // Fifteens: {4,5,6}=15 and {3,3,4,5}=15 -> 2 combos = 4 pts.
    // Pairs: the two 3s -> 1 pair = 2 pts.
    // Runs: 3-4-5-6 present twice (once per 3) -> length 4 x 2 instances = 8 pts.
    // Flush/nobs: 0 (mixed suits, no jack).
    // Total: 4 + 2 + 8 = 14.
    @Test func doubleRunOfFour() {
        let hand = [
            Card(rank: .three, suit: .spades),
            Card(rank: .three, suit: .clubs),
            Card(rank: .four, suit: .diamonds),
            Card(rank: .five, suit: .hearts)
        ]
        let starter = Card(rank: .six, suit: .spades)

        let breakdown = Scorer.score(hand: hand, starter: starter, isCrib: false)

        #expect(breakdown.fifteens.reduce(0) { $0 + $1.points } == 4)
        #expect(breakdown.pairs.reduce(0) { $0 + $1.points } == 2)
        #expect(breakdown.runs.reduce(0) { $0 + $1.points } == 8)
        #expect(breakdown.total == 14)
    }

    // MARK: - Flush rules: hand vs. crib, matching vs. non-matching starter
    // All four use the same zero-scoring rank set (K, 2, 4, 6 + starter J) so flush is
    // isolated from every other category.
    @Test func handFlushScoresFourWithMismatchedStarter() {
        let hand = [
            Card(rank: .king, suit: .clubs),
            Card(rank: .two, suit: .clubs),
            Card(rank: .four, suit: .clubs),
            Card(rank: .six, suit: .clubs)
        ]
        let starter = Card(rank: .jack, suit: .spades)

        let breakdown = Scorer.score(hand: hand, starter: starter, isCrib: false)

        #expect(breakdown.flush.reduce(0) { $0 + $1.points } == 4)
        #expect(breakdown.total == 4)
    }

    @Test func handFlushScoresFiveWithMatchingStarter() {
        let hand = [
            Card(rank: .king, suit: .clubs),
            Card(rank: .two, suit: .clubs),
            Card(rank: .four, suit: .clubs),
            Card(rank: .six, suit: .clubs)
        ]
        let starter = Card(rank: .jack, suit: .clubs)

        let breakdown = Scorer.score(hand: hand, starter: starter, isCrib: false)

        #expect(breakdown.flush.reduce(0) { $0 + $1.points } == 5)
        #expect(breakdown.total == 5)
    }

    @Test func cribFlushScoresNothingWithMismatchedStarter() {
        let crib = [
            Card(rank: .king, suit: .clubs),
            Card(rank: .two, suit: .clubs),
            Card(rank: .four, suit: .clubs),
            Card(rank: .six, suit: .clubs)
        ]
        let starter = Card(rank: .jack, suit: .spades)

        let breakdown = Scorer.score(hand: crib, starter: starter, isCrib: true)

        #expect(breakdown.flush.isEmpty)
        #expect(breakdown.total == 0)
    }

    @Test func cribFlushScoresFiveWithMatchingStarter() {
        let crib = [
            Card(rank: .king, suit: .clubs),
            Card(rank: .two, suit: .clubs),
            Card(rank: .four, suit: .clubs),
            Card(rank: .six, suit: .clubs)
        ]
        let starter = Card(rank: .jack, suit: .clubs)

        let breakdown = Scorer.score(hand: crib, starter: starter, isCrib: true)

        #expect(breakdown.flush.reduce(0) { $0 + $1.points } == 5)
        #expect(breakdown.total == 5)
    }

    // MARK: - Invariants across the full deck (regression net)

    @Test func standardDeckHasFiftyTwoUniqueCards() {
        #expect(Deck.standard52.count == 52)
        #expect(Set(Deck.standard52).count == 52)
    }

    @Test func noHandCanScoreAboveTwentyNine() {
        // The 29-hand is the published maximum; spot-check a large but bounded sample
        // of hands rather than all 2,598,960 five-card combinations (too slow for a
        // unit test), to catch any gross over-counting bug in the subset enumeration.
        let deck = Deck.standard52
        var checked = 0
        for i in stride(from: 0, to: deck.count, by: 3) {
            for j in stride(from: 1, to: deck.count, by: 7) where j != i {
                let hand = [deck[i], deck[j], deck[(i + 10) % deck.count], deck[(j + 20) % deck.count]]
                let uniqueRanksSuits = Set(hand.map { "\($0.rank.rawValue)-\($0.suit.rawValue)" })
                guard uniqueRanksSuits.count == 4 else { continue }
                let starter = deck[(i + j + 5) % deck.count]
                guard !hand.contains(starter) else { continue }
                let breakdown = Scorer.score(hand: hand, starter: starter, isCrib: false)
                #expect(breakdown.total <= 29)
                checked += 1
            }
        }
        #expect(checked > 100)
    }
}
