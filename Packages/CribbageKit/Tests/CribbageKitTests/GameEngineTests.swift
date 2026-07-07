import Testing
@testable import CribbageKit

/// A fixed, non-random seed for tests that need `.dealHand` to fire but don't care what
/// the actual shuffle produces.
private func testSeed(_ value: UInt64 = 1) -> Seed256 {
    Seed256(a: value, b: value, c: value, d: value)
}

struct GameEngineTests {
    // MARK: - Dealing

    @Test func dealHandDealsSixEachFromAFullDeck() {
        let dealt = GameEngine.reduce(GameState(), applying: .dealHand(seed: testSeed(42)))

        #expect(dealt.hands.playerOne.count == 6)
        #expect(dealt.hands.playerTwo.count == 6)
        #expect(dealt.deck.count == 40)
        #expect(dealt.phase == .discarding)
        #expect(dealt.currentSeed == testSeed(42))

        let allDealt = dealt.hands.playerOne + dealt.hands.playerTwo + dealt.deck
        #expect(Set(allDealt).count == 52)
    }

    @Test func dealHandAlternatesDealerOnlyAfterCounting() {
        var state = GameState(dealer: .playerOne)
        state = GameEngine.reduce(state, applying: .dealHand(seed: testSeed(7)))
        #expect(state.dealer == .playerOne) // very first deal never flips

        state.phase = .counting // simulate a completed hand
        state = GameEngine.reduce(state, applying: .dealHand(seed: testSeed(8)))
        #expect(state.dealer == .playerTwo)
    }

    // MARK: - Discarding

    @Test func discardingBothSeatsAdvancesToCutStarter() {
        var state = GameEngine.reduce(GameState(), applying: .dealHand(seed: testSeed()))

        let firstDiscard = Array(state.hands.playerOne.prefix(2))
        state = GameEngine.reduce(state, applying: .discard(seat: .playerOne, cards: firstDiscard))
        #expect(state.hands.playerOne.count == 4)
        #expect(state.phase == .discarding) // still waiting on playerTwo

        let secondDiscard = Array(state.hands.playerTwo.prefix(2))
        state = GameEngine.reduce(state, applying: .discard(seat: .playerTwo, cards: secondDiscard))
        #expect(state.hands.playerTwo.count == 4)
        #expect(state.crib.count == 4)
        #expect(state.phase == .cutStarter)
    }

    // MARK: - Cutting the starter

    @Test func cutForStarterAwardsHisHeelsWhenStarterIsAJack() {
        var state = GameState(dealer: .playerOne)
        state.hands = PerSeat(
            playerOne: [
                Card(rank: .two, suit: .spades), Card(rank: .four, suit: .spades),
                Card(rank: .six, suit: .spades), Card(rank: .eight, suit: .spades)
            ],
            playerTwo: [
                Card(rank: .two, suit: .clubs), Card(rank: .four, suit: .clubs),
                Card(rank: .six, suit: .clubs), Card(rank: .eight, suit: .clubs)
            ]
        )
        let restOfDeck = Deck.standard52.filter { $0.rank != .jack || $0.suit != .diamonds }
        state.deck = [Card(rank: .jack, suit: .diamonds)] + restOfDeck
        state.phase = .cutStarter

        let next = GameEngine.reduce(state, applying: .cutForStarter)

        #expect(next.starter == Card(rank: .jack, suit: .diamonds))
        #expect(next.scores.playerOne == 2) // playerOne is the dealer
        #expect(next.hisHeelsEvent?.kind == .hisHeels) // recorded as a real event, not a silent +2
        #expect(next.hisHeelsEvent?.points == 2)
        #expect(next.phase == .pegging)
        #expect(next.turnToAct == .playerTwo) // non-dealer leads pegging
        #expect(next.peggingRemaining.playerOne.count == 4)
    }

    // MARK: - "One for last card"

    @Test func playingTheFinalCardBelowThirtyOnePegsOneForLastCard() {
        var state = GameState(dealer: .playerTwo)
        // A verified zero-scoring hand (with a non-jack starter) for both seats and the
        // crib, so the only points in play come from pegging.
        let zeroScoringHand = [
            Card(rank: .king, suit: .spades), Card(rank: .two, suit: .clubs),
            Card(rank: .four, suit: .diamonds), Card(rank: .six, suit: .hearts)
        ]
        state.hands = PerSeat(playerOne: zeroScoringHand, playerTwo: zeroScoringHand)
        state.crib = zeroScoringHand
        state.starter = Card(rank: .queen, suit: .spades)
        state.currentSeed = testSeed()
        state.phase = .pegging
        state.peggingRemaining = PerSeat(
            playerOne: [Card(rank: .three, suit: .spades)],
            playerTwo: [Card(rank: .eight, suit: .clubs)]
        )
        state.turnToAct = .playerOne

        var next = GameEngine.reduce(state, applying: .playCard(seat: .playerOne, card: Card(rank: .three, suit: .spades)))
        #expect(next.scores.playerOne == 0) // count is 3, playerTwo still holds a card

        // count becomes 11 (no 15/31/pair/run), but playerTwo played the phase's last card.
        next = GameEngine.reduce(next, applying: .playCard(seat: .playerTwo, card: Card(rank: .eight, suit: .clubs)))
        #expect(next.phase == .counting)
        #expect(next.scores.playerTwo == 1) // the sole point this hand is 1 for last card
        #expect(next.scores.playerOne == 0)
        #expect(next.lastRoundSummary?.dealerPegging.contains { $0.kind == .go && $0.points == 1 } == true)
    }

    // MARK: - Pegging scoring (isolated, via the pure scoring helper)

    @Test func peggingScoresFifteen() {
        let pile = [Card(rank: .seven, suit: .spades), Card(rank: .eight, suit: .clubs)]
        let events = GameEngine.peggingScoreForLatestPlay(pile: pile, count: 15, ruleset: .standard)
        #expect(events.contains { $0.kind == .fifteen && $0.points == 2 })
    }

    @Test func peggingScoresThirtyOneExactly() {
        let pile = [
            Card(rank: .king, suit: .spades), Card(rank: .queen, suit: .clubs),
            Card(rank: .jack, suit: .diamonds), Card(rank: .ace, suit: .hearts)
        ]
        let events = GameEngine.peggingScoreForLatestPlay(pile: pile, count: 31, ruleset: .standard)
        #expect(events.count == 1)
        #expect(events[0].kind == .thirtyOne)
        #expect(events[0].points == 2)
    }

    @Test func peggingScoresPairRoyal() {
        let pile = [
            Card(rank: .nine, suit: .spades), Card(rank: .nine, suit: .clubs), Card(rank: .nine, suit: .diamonds)
        ]
        let events = GameEngine.peggingScoreForLatestPlay(pile: pile, count: 27, ruleset: .standard)
        #expect(events.count == 1)
        #expect(events[0].kind == .pair)
        #expect(events[0].points == 6)
    }

    @Test func peggingScoresRunOfThree() {
        let pile = [
            Card(rank: .two, suit: .spades), Card(rank: .four, suit: .clubs), Card(rank: .three, suit: .diamonds)
        ]
        let events = GameEngine.peggingScoreForLatestPlay(pile: pile, count: 9, ruleset: .standard)
        #expect(events.count == 1)
        #expect(events[0].kind == .run)
        #expect(events[0].points == 3)
    }

    // MARK: - Pegging turn-passing and "go" resolution

    @Test func sayGoAwardsThePointToTheLastPlayerAndReturnsLeadToTheFirstGoSayer() {
        var state = GameState(dealer: .playerTwo)
        // Placeholder kept hands / crib only to satisfy Scorer's 4-card precondition if
        // this test's moves happened to exhaust pegging — they don't, so the values here
        // don't otherwise matter.
        let placeholderHand = [
            Card(rank: .two, suit: .hearts), Card(rank: .four, suit: .diamonds),
            Card(rank: .six, suit: .hearts), Card(rank: .eight, suit: .diamonds)
        ]
        state.hands = PerSeat(playerOne: placeholderHand, playerTwo: placeholderHand)
        state.crib = placeholderHand
        state.starter = Card(rank: .five, suit: .clubs)
        state.phase = .pegging
        state.peggingRemaining = PerSeat(
            playerOne: [Card(rank: .jack, suit: .spades)],
            playerTwo: [Card(rank: .queen, suit: .clubs)]
        )
        // A count of 25 leaves no legal play for either 10-pip card remaining.
        state.peggingPile = [
            Card(rank: .king, suit: .hearts), Card(rank: .king, suit: .diamonds), Card(rank: .five, suit: .spades)
        ]
        state.peggingCount = 25
        state.turnToAct = .playerOne
        state.goSeat = nil
        state.lastCardPlayedBy = .playerTwo

        let afterFirstGo = GameEngine.reduce(state, applying: .sayGo(seat: .playerOne))
        #expect(afterFirstGo.goSeat == .playerOne)
        #expect(afterFirstGo.turnToAct == .playerTwo)
        #expect(afterFirstGo.peggingCount == 25) // unchanged — the run hasn't ended yet

        let afterSecondGo = GameEngine.reduce(afterFirstGo, applying: .sayGo(seat: .playerTwo))
        #expect(afterSecondGo.scores.playerTwo == 1) // "go" point to whoever played last
        #expect(afterSecondGo.peggingCount == 0)
        #expect(afterSecondGo.peggingPile.isEmpty)
        #expect(afterSecondGo.goSeat == nil)
        #expect(afterSecondGo.turnToAct == .playerOne) // the original go-sayer leads the fresh run
        #expect(afterSecondGo.phase == .pegging) // both seats still hold a card
    }

    /// Regression test for a real bug found while designing PeggingSolver: after one seat
    /// says go, the other seat must be able to play *multiple* cards in a row (the count
    /// only goes up, so the go-sayer is guaranteed to still be stuck) — the turn must not
    /// bounce back to them after every single play.
    @Test func afterAGoTheOtherSeatKeepsPlayingMultipleCardsWithoutTheTurnBouncingBack() {
        var state = GameState(dealer: .playerTwo)
        let placeholderHand = [
            Card(rank: .two, suit: .hearts), Card(rank: .four, suit: .diamonds),
            Card(rank: .six, suit: .hearts), Card(rank: .eight, suit: .diamonds)
        ]
        state.hands = PerSeat(playerOne: placeholderHand, playerTwo: placeholderHand)
        state.crib = placeholderHand
        state.starter = Card(rank: .five, suit: .clubs)
        state.phase = .pegging
        state.peggingRemaining = PerSeat(
            playerOne: [Card(rank: .king, suit: .spades)],
            playerTwo: [Card(rank: .ace, suit: .clubs), Card(rank: .two, suit: .diamonds)]
        )
        state.peggingPile = [
            Card(rank: .nine, suit: .hearts), Card(rank: .king, suit: .diamonds), Card(rank: .six, suit: .clubs)
        ]
        state.peggingCount = 25 // playerOne's only card (a king, pip 10) would bust to 35
        state.turnToAct = .playerOne
        state.goSeat = nil

        let afterGo = GameEngine.reduce(state, applying: .sayGo(seat: .playerOne))
        #expect(afterGo.goSeat == .playerOne)
        #expect(afterGo.turnToAct == .playerTwo)

        let aceOfClubs = Card(rank: .ace, suit: .clubs)
        let afterFirstPlay = GameEngine.reduce(afterGo, applying: .playCard(seat: .playerTwo, card: aceOfClubs))
        #expect(afterFirstPlay.peggingCount == 26)
        #expect(afterFirstPlay.turnToAct == .playerTwo) // stays — playerOne is still stuck

        let afterSecondPlay = GameEngine.reduce(
            afterFirstPlay, applying: .playCard(seat: .playerTwo, card: Card(rank: .two, suit: .diamonds))
        )
        #expect(afterSecondPlay.peggingCount == 28)
        #expect(afterSecondPlay.peggingRemaining.playerTwo.isEmpty)
        #expect(afterSecondPlay.turnToAct == .playerTwo) // still stays, even though they're now out of cards
        #expect(afterSecondPlay.phase == .pegging) // playerOne's king hasn't been played yet
    }

    @Test func peggingEndsAndBeginsCountingOnceBothHandsAreExhausted() {
        var state = GameState(dealer: .playerTwo)
        // The verified zero-point combination from ScorerTests.zeroPointHand, reused for
        // both hands and the crib so this test isolates the pegging-run score cleanly.
        let zeroScoringHand = [
            Card(rank: .king, suit: .spades), Card(rank: .two, suit: .clubs),
            Card(rank: .four, suit: .diamonds), Card(rank: .six, suit: .hearts)
        ]
        state.hands = PerSeat(playerOne: zeroScoringHand, playerTwo: zeroScoringHand)
        state.crib = zeroScoringHand
        state.starter = Card(rank: .jack, suit: .spades)
        state.currentSeed = testSeed()
        state.phase = .pegging
        state.peggingRemaining = PerSeat(
            playerOne: [Card(rank: .ten, suit: .spades), Card(rank: .nine, suit: .clubs)],
            playerTwo: [Card(rank: .jack, suit: .diamonds)]
        )
        state.turnToAct = .playerOne

        let tenSpades = Card(rank: .ten, suit: .spades)
        var next = GameEngine.reduce(state, applying: .playCard(seat: .playerOne, card: tenSpades))
        #expect(next.peggingCount == 10)
        #expect(next.turnToAct == .playerTwo)

        next = GameEngine.reduce(next, applying: .playCard(seat: .playerTwo, card: Card(rank: .jack, suit: .diamonds)))
        #expect(next.peggingCount == 20)
        #expect(next.turnToAct == .playerOne)

        // Ranks in the pile so far: ten(10), jack(11); playing nine(9) completes a run of
        // three consecutive ranks {9,10,11} for 3 points, and empties both hands. Playing
        // the final card of the phase (count 29, not 31) also pegs 1 for last card, so 4.
        next = GameEngine.reduce(next, applying: .playCard(seat: .playerOne, card: Card(rank: .nine, suit: .clubs)))
        #expect(next.scores.playerOne == 4)
        #expect(next.phase == .counting)
        #expect(next.peggingRemaining.playerOne.isEmpty)
        #expect(next.peggingRemaining.playerTwo.isEmpty)
        #expect(next.lastRoundSummary != nil)
    }

    // MARK: - Counting short-circuits the moment someone reaches the target

    @Test func gameEndsImmediatelyIfNonDealerHandAloneReachesTarget() {
        var state = GameState(ruleset: Ruleset(gameTarget: 10), dealer: .playerTwo)
        // Non-dealer (playerOne) holds a hand worth well over 10 on its own: four 5s.
        state.hands = PerSeat(
            playerOne: [
                Card(rank: .five, suit: .spades), Card(rank: .five, suit: .clubs),
                Card(rank: .five, suit: .diamonds), Card(rank: .five, suit: .hearts)
            ],
            playerTwo: [
                Card(rank: .two, suit: .spades), Card(rank: .four, suit: .spades),
                Card(rank: .six, suit: .spades), Card(rank: .eight, suit: .spades)
            ]
        )
        state.crib = [
            Card(rank: .two, suit: .clubs), Card(rank: .four, suit: .clubs),
            Card(rank: .six, suit: .clubs), Card(rank: .eight, suit: .clubs)
        ]
        state.starter = Card(rank: .nine, suit: .hearts)
        state.currentSeed = testSeed()
        state.phase = .pegging
        state.peggingRemaining = PerSeat(playerOne: [], playerTwo: [Card(rank: .ace, suit: .hearts)])
        // Force the transition into counting by playing the very last remaining card.
        state.turnToAct = .playerTwo

        let lastCard = Card(rank: .ace, suit: .hearts)
        let next = GameEngine.reduce(state, applying: .playCard(seat: .playerTwo, card: lastCard))

        #expect(next.phase == .gameOver)
        #expect(next.winner == .playerOne)
        #expect(next.lastRoundSummary?.dealerHand == nil) // short-circuited before scoring the dealer's hand
        #expect(next.lastRoundSummary?.crib == nil)
    }

    // MARK: - Skunk detection

    @Test func skunkResultReflectsTheLosersFinalScore() {
        var state = GameState()
        state.phase = .gameOver
        state.winner = .playerOne
        state.scores = PerSeat(playerOne: 121, playerTwo: 75)
        #expect(state.skunkResult == .skunk) // 75 < 91

        state.scores.playerTwo = 55
        #expect(state.skunkResult == .doubleSkunk) // 55 < 61

        state.scores.playerTwo = 100
        #expect(state.skunkResult == .normal)
    }
}
