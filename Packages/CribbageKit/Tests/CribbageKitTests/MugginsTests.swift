import Testing
@testable import CribbageKit

/// Muggins is a house rule (`Ruleset.mugginsEnabled`, off by default): the show becomes
/// interactive — each player claims their own hand/crib, and any points they miss can be
/// pegged ("mugginsed") by the opponent.
struct MugginsTests {
    private let zeroHand = [
        Card(rank: .king, suit: .spades), Card(rank: .two, suit: .clubs),
        Card(rank: .four, suit: .diamonds), Card(rank: .six, suit: .hearts)
    ]

    /// A `.counting` state with muggins on, the non-dealer's hand up first with an explicit
    /// `trueValue`, and zero-scoring dealer hand + crib so the later items are worth 0.
    private func countingState(nonDealerHandValue: Int, scores: PerSeat<Int> = PerSeat(playerOne: 0, playerTwo: 0)) -> GameState {
        var state = GameState(ruleset: Ruleset(mugginsEnabled: true), dealer: .playerTwo)
        state.phase = .counting
        state.starter = Card(rank: .queen, suit: .spades) // keeps zeroHand worth 0
        state.hands = PerSeat(playerOne: zeroHand, playerTwo: zeroHand)
        state.crib = zeroHand
        state.scores = scores
        // playerOne is the non-dealer (dealer is playerTwo).
        state.pendingCount = PendingCount(item: .nonDealerHand, owner: .playerOne, trueValue: nonDealerHandValue)
        return state
    }

    // MARK: - Off by default

    @Test func mugginsOffCountsAutomaticallyAndLeavesNoPendingCount() {
        // Reuse the standard (muggins-off) pegging-exhaustion path.
        var state = GameState(dealer: .playerTwo)
        state.hands = PerSeat(playerOne: zeroHand, playerTwo: zeroHand)
        state.crib = zeroHand
        state.starter = Card(rank: .jack, suit: .spades)
        state.currentSeed = Seed256(a: 1, b: 1, c: 1, d: 1)
        state.phase = .pegging
        state.peggingRemaining = PerSeat(
            playerOne: [Card(rank: .ten, suit: .spades)],
            playerTwo: [Card(rank: .nine, suit: .clubs)]
        )
        state.turnToAct = .playerOne
        var next = GameEngine.reduce(state, applying: .playCard(seat: .playerOne, card: Card(rank: .ten, suit: .spades)))
        next = GameEngine.reduce(next, applying: .playCard(seat: .playerTwo, card: Card(rank: .nine, suit: .clubs)))
        #expect(next.phase == .counting)
        #expect(next.pendingCount == nil) // no interactive counting when muggins is off
    }

    // MARK: - beginCounting hands off to interactive claiming

    @Test func mugginsOnDefersScoringAndAwaitsTheNonDealersClaim() {
        var state = GameState(ruleset: Ruleset(mugginsEnabled: true), dealer: .playerTwo)
        // Non-dealer (playerOne) hand worth a known 4: 7,8 make 15 (2) + 7,8,9 run? keep it
        // simple — 6,7,8,9 with a non-scoring starter is a run of 4 (4) but also 6+9,7+8
        // fifteens. Use a hand whose value we assert against Scorer directly instead.
        let nonDealerHand = [
            Card(rank: .six, suit: .clubs), Card(rank: .seven, suit: .diamonds),
            Card(rank: .eight, suit: .hearts), Card(rank: .nine, suit: .spades)
        ]
        state.hands = PerSeat(playerOne: nonDealerHand, playerTwo: zeroHand)
        state.crib = zeroHand
        state.starter = Card(rank: .king, suit: .spades)
        state.currentSeed = Seed256(a: 1, b: 1, c: 1, d: 1)
        state.phase = .pegging
        // Non-dealer plays their last card to trigger beginCounting (dealer already out).
        state.peggingRemaining = PerSeat(playerOne: [Card(rank: .ace, suit: .clubs)], playerTwo: [])
        state.turnToAct = .playerOne

        let next = GameEngine.reduce(state, applying: .playCard(seat: .playerOne, card: Card(rank: .ace, suit: .clubs)))
        #expect(next.phase == .counting)
        // Only the pegging point (1 for last card) has been scored — no hand/crib points yet.
        #expect(next.scores.playerOne == 1)
        #expect(next.scores.playerTwo == 0)
        let expectedValue = Scorer.score(hand: nonDealerHand, starter: next.starter!, isCrib: false).total
        #expect(next.pendingCount?.item == .nonDealerHand)
        #expect(next.pendingCount?.owner == .playerOne)
        #expect(next.pendingCount?.stage == .awaitingClaim)
        #expect(next.pendingCount?.trueValue == expectedValue)
        #expect(GameEngine.seatToActNext(in: next) == .playerOne)
    }

    // MARK: - Claiming

    @Test func exactClaimAwardsFullValueAndAdvancesWithNoMugginsWindow() {
        let state = countingState(nonDealerHandValue: 8)
        let next = GameEngine.reduce(state, applying: .claimScore(seat: .playerOne, points: 8))
        #expect(next.scores.playerOne == 8)
        #expect(next.pendingCount?.item == .dealerHand)
        #expect(next.pendingCount?.owner == .playerTwo)
        #expect(next.pendingCount?.stage == .awaitingClaim)
        #expect(next.pendingCount?.trueValue == 0) // zero-scoring dealer hand
    }

    @Test func overClaimIsCappedAtTheTrueValue() {
        let state = countingState(nonDealerHandValue: 8)
        let next = GameEngine.reduce(state, applying: .claimScore(seat: .playerOne, points: 20))
        #expect(next.scores.playerOne == 8) // capped, no bonus for over-claiming
        #expect(next.pendingCount?.item == .dealerHand) // no muggins window (nothing missed)
    }

    @Test func underClaimOpensAMugginsWindowThatTheOpponentCanTake() {
        let state = countingState(nonDealerHandValue: 8)
        let claimed = GameEngine.reduce(state, applying: .claimScore(seat: .playerOne, points: 5))
        #expect(claimed.scores.playerOne == 5)
        #expect(claimed.pendingCount?.stage == .awaitingMuggins)
        #expect(claimed.pendingCount?.shortfall == 3)
        #expect(claimed.pendingCount?.item == .nonDealerHand) // still on the same item
        #expect(GameEngine.seatToActNext(in: claimed) == .playerTwo) // opponent decides

        let mugginsed = GameEngine.reduce(claimed, applying: .callMuggins(seat: .playerTwo))
        #expect(mugginsed.scores.playerOne == 5)
        #expect(mugginsed.scores.playerTwo == 3) // opponent pegs the missed 3
        #expect(mugginsed.pendingCount?.item == .dealerHand) // advanced
    }

    @Test func underClaimThatIsPassedLetsTheMissedPointsGo() {
        let state = countingState(nonDealerHandValue: 8)
        let claimed = GameEngine.reduce(state, applying: .claimScore(seat: .playerOne, points: 5))
        let passed = GameEngine.reduce(claimed, applying: .passMuggins(seat: .playerTwo))
        #expect(passed.scores.playerOne == 5)
        #expect(passed.scores.playerTwo == 0) // missed points simply lost
        #expect(passed.pendingCount?.item == .dealerHand) // advanced
    }

    // MARK: - Full show completes

    @Test func countingAllThreeItemsClearsThePendingCount() {
        var next = countingState(nonDealerHandValue: 4)
        next = GameEngine.reduce(next, applying: .claimScore(seat: .playerOne, points: 4)) // non-dealer hand
        next = GameEngine.reduce(next, applying: .claimScore(seat: .playerTwo, points: 0)) // dealer hand (0)
        next = GameEngine.reduce(next, applying: .claimScore(seat: .playerTwo, points: 0)) // crib (0)
        #expect(next.pendingCount == nil) // show complete
        #expect(next.phase == .counting)
        #expect(next.scores.playerOne == 4)
        #expect(next.scores.playerTwo == 0)
    }

    // MARK: - Winning mid-show short-circuits

    @Test func reachingTheTargetOnAClaimEndsTheGameImmediately() {
        let state = countingState(nonDealerHandValue: 8, scores: PerSeat(playerOne: 118, playerTwo: 0))
        let next = GameEngine.reduce(state, applying: .claimScore(seat: .playerOne, points: 8))
        #expect(next.phase == .gameOver)
        #expect(next.winner == .playerOne)
        #expect(next.pendingCount == nil)
    }

    @Test func reachingTheTargetViaMugginsEndsTheGameImmediately() {
        let state = countingState(nonDealerHandValue: 8, scores: PerSeat(playerOne: 0, playerTwo: 119))
        let claimed = GameEngine.reduce(state, applying: .claimScore(seat: .playerOne, points: 5)) // shortfall 3
        let next = GameEngine.reduce(claimed, applying: .callMuggins(seat: .playerTwo))
        #expect(next.scores.playerTwo == 122)
        #expect(next.phase == .gameOver)
        #expect(next.winner == .playerTwo)
        #expect(next.pendingCount == nil)
    }
}
