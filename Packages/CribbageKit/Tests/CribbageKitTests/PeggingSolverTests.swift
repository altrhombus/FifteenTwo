import Testing
@testable import CribbageKit

/// Every expected outcome below is traced by hand through the full (small, fully forced
/// or fully enumerable) game tree — see docs/plan.md ("no guessing").
struct PeggingSolverTests {
    @Test func bothHandsSingleCardForcedSequenceScoresTheFifteenCorrectly() {
        // I play 7, they're forced to play 8 (their only card) making 15 — 2 points to them.
        let option = PeggingSolver.bestPlay(
            mine: [Card(rank: .seven, suit: .spades)],
            theirs: [Card(rank: .eight, suit: .clubs)],
            pile: []
        )
        #expect(option.card == Card(rank: .seven, suit: .spades))
        #expect(option.netScore == -2)
    }

    @Test func choosesTheLeadThatAvoidsGiftingAnEasyFifteen() {
        // Leading 5 lets their forced 10 hit fifteen (bad for me); leading 9 avoids it.
        let option = PeggingSolver.bestPlay(
            mine: [Card(rank: .five, suit: .spades), Card(rank: .nine, suit: .clubs)],
            theirs: [Card(rank: .ten, suit: .diamonds)],
            pile: []
        )
        #expect(option.card == Card(rank: .nine, suit: .clubs))
        #expect(option.netScore == 0)
    }

    @Test func noLegalPlayReturnsNilCardAndTracesTheForcedDoubleGoAndReset() {
        // Both hold a king (pip 10) at count 25 — neither can play (would bust to 35).
        // The double-go resets to 0; I'm forced to lead my king into their matching
        // king, which pairs — 2 points to them. No "go" point either way since nobody
        // played a card during the go itself.
        let option = PeggingSolver.bestPlay(
            mine: [Card(rank: .king, suit: .spades)],
            theirs: [Card(rank: .king, suit: .clubs)],
            pile: [Card(rank: .nine, suit: .hearts), Card(rank: .king, suit: .diamonds), Card(rank: .six, suit: .clubs)]
        )
        #expect(option.card == nil)
        #expect(option.netScore == -2)
    }

    @Test func liveSamplingReturnsALegalCardFromMyHand() {
        var rng = SeededGenerator(seed: 99)
        let mine = [Card(rank: .four, suit: .spades), Card(rank: .seven, suit: .clubs)]
        let unseen = Deck.standard52.filter { !mine.contains($0) && $0 != Card(rank: .queen, suit: .hearts) }

        let option = PeggingSolver.bestPlay(
            mine: mine, unseenCards: unseen, opponentCardCount: 3, pile: [], sampleCount: 30, using: &rng
        )

        #expect(option.card != nil)
        #expect(mine.contains(option.card!))
    }

    @Test func liveSamplingWithNoLegalPlayReturnsNilCard() {
        var rng = SeededGenerator(seed: 7)
        let mine = [Card(rank: .king, suit: .spades)]
        let unseen = Deck.standard52.filter { !mine.contains($0) }

        let pile = [
            Card(rank: .king, suit: .hearts), Card(rank: .king, suit: .diamonds), Card(rank: .five, suit: .clubs)
        ]
        let option = PeggingSolver.bestPlay(
            mine: mine,
            unseenCards: unseen,
            opponentCardCount: 2,
            pile: pile,
            sampleCount: 20,
            using: &rng
        )

        #expect(option.card == nil)
    }
}
