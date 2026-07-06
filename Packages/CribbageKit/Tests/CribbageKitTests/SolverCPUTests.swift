import Testing
@testable import CribbageKit

struct SolverCPUTests {
    private let sampleHand = [
        Card(rank: .three, suit: .spades), Card(rank: .four, suit: .clubs),
        Card(rank: .five, suit: .diamonds), Card(rank: .six, suit: .hearts),
        Card(rank: .ten, suit: .spades), Card(rank: .king, suit: .clubs)
    ]

    @Test func expertDiscardAlwaysMatchesTheSolversTopChoice() {
        // The solver's ranking doesn't depend on the RNG at all, so this only needs to
        // confirm chooseDiscard(difficulty: .expert) always resolves to options[0]
        // regardless of which seed happens to be in play — a couple of seeds suffice.
        let best = DiscardSolver.bestDiscards(hand: sampleHand, isDealer: false)[0]
        for seed in UInt64(0)..<3 {
            var rng = SeededGenerator(seed: seed)
            let discard = SolverCPU.chooseDiscard(
                from: sampleHand, isDealer: false, difficulty: .expert, using: &rng
            )
            #expect(Set(discard) == Set(best.discarded))
        }
    }

    @Test func discardIsAlwaysTwoCardsFromTheOriginalHandAtEveryDifficulty() {
        var rng = SeededGenerator(seed: 42)
        for difficulty in CPUDifficulty.allCases {
            let discard = SolverCPU.chooseDiscard(from: sampleHand, isDealer: true, difficulty: difficulty, using: &rng)
            #expect(discard.count == 2)
            #expect(Set(discard).isSubset(of: Set(sampleHand)))
        }
    }

    @Test func peggingPlayIsAlwaysLegalAtEveryDifficulty() {
        var rng = SeededGenerator(seed: 5)
        let mine = [Card(rank: .four, suit: .spades), Card(rank: .seven, suit: .clubs)]
        let unseen = Deck.standard52.filter { !mine.contains($0) }
        let pile = [Card(rank: .king, suit: .hearts)]

        for difficulty in CPUDifficulty.allCases {
            let card = SolverCPU.choosePeggingPlay(
                mine: mine, unseenCards: unseen, opponentCardCount: 3, pile: pile, difficulty: difficulty, using: &rng
            )
            #expect(card != nil)
            #expect(mine.contains(card!))
        }
    }

    @Test func peggingPlayReturnsNilWhenNoLegalPlayExists() {
        var rng = SeededGenerator(seed: 9)
        let mine = [Card(rank: .king, suit: .spades)]
        let unseen = Deck.standard52.filter { !mine.contains($0) }
        let pile = [
            Card(rank: .king, suit: .hearts), Card(rank: .king, suit: .diamonds), Card(rank: .five, suit: .clubs)
        ]

        let card = SolverCPU.choosePeggingPlay(
            mine: mine, unseenCards: unseen, opponentCardCount: 2, pile: pile, difficulty: .expert, using: &rng
        )
        #expect(card == nil)
    }
}
