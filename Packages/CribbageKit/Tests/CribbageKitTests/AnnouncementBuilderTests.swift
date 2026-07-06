import Testing
@testable import CribbageKit

struct AnnouncementBuilderTests {
    // MARK: - Discards never leak hidden information

    @Test func yourOwnDiscardIsNamedButOpponentsDiscardIsNotEvenWhenListeningAsThem() {
        let cards = [Card(rank: .three, suit: .clubs), Card(rank: .king, suit: .hearts)]
        let before = GameState()
        let after = before

        let asDiscarder = AnnouncementBuilder.announcements(
            before: before, after: after, move: .discard(seat: .playerOne, cards: cards), listenerSeat: .playerOne
        )
        #expect(asDiscarder.contains { $0.contains("King") && $0.contains("Hearts") })

        let asOpponent = AnnouncementBuilder.announcements(
            before: before, after: after, move: .discard(seat: .playerOne, cards: cards), listenerSeat: .playerTwo
        )
        #expect(!asOpponent.contains { $0.contains("King") })
        #expect(!asOpponent.contains { $0.contains("Three") })
        #expect(asOpponent.contains { $0.contains("Opponent") && $0.contains("discarded") })
    }

    // MARK: - Starter cut and his heels

    @Test func starterCutAnnouncesTheCardAndHisHeelsWhenListenerIsDealer() {
        var after = GameState(dealer: .playerOne)
        after.starter = Card(rank: .jack, suit: .diamonds)
        after.phase = .pegging

        let lines = AnnouncementBuilder.announcements(
            before: GameState(dealer: .playerOne), after: after, move: .cutForStarter, listenerSeat: .playerOne
        )
        #expect(lines.contains("Starter card: Jack of Diamonds."))
        #expect(lines.contains { $0.contains("You score 2 for his heels") })
    }

    @Test func starterCutAnnouncesOpponentsHisHeelsWhenListenerIsNotDealer() {
        var after = GameState(dealer: .playerOne)
        after.starter = Card(rank: .jack, suit: .diamonds)
        after.phase = .pegging

        let lines = AnnouncementBuilder.announcements(
            before: GameState(dealer: .playerOne), after: after, move: .cutForStarter, listenerSeat: .playerTwo
        )
        #expect(lines.contains { $0.contains("Opponent scores 2 for his heels") })
    }

    @Test func starterCutWithoutAJackHasNoHisHeelsLine() {
        var after = GameState(dealer: .playerOne)
        after.starter = Card(rank: .seven, suit: .diamonds)

        let lines = AnnouncementBuilder.announcements(
            before: GameState(dealer: .playerOne), after: after, move: .cutForStarter, listenerSeat: .playerOne
        )
        #expect(lines == ["Starter card: 7 of Diamonds."])
    }

    // MARK: - Pegging plays and score deltas

    @Test func playedCardAnnouncesWhoPlayedAndTheNewCount() {
        var before = GameState()
        before.peggingCount = 10
        var after = before
        after.peggingCount = 17

        let card = Card(rank: .seven, suit: .spades)
        let lines = AnnouncementBuilder.announcements(
            before: before, after: after, move: .playCard(seat: .playerOne, card: card), listenerSeat: .playerOne
        )
        #expect(lines.first == "You played 7 of Spades. Count is 17.")

        let opponentLines = AnnouncementBuilder.announcements(
            before: before, after: after, move: .playCard(seat: .playerOne, card: card), listenerSeat: .playerTwo
        )
        #expect(opponentLines.first == "Opponent played 7 of Spades. Count is 17.")
    }

    @Test func scoringDuringPeggingIsAnnouncedForTheRightSeat() {
        var before = GameState()
        before.scores = PerSeat(playerOne: 0, playerTwo: 0)
        var after = before
        after.scores = PerSeat(playerOne: 2, playerTwo: 0)

        let card = Card(rank: .eight, suit: .spades)
        let lines = AnnouncementBuilder.announcements(
            before: before, after: after, move: .playCard(seat: .playerOne, card: card), listenerSeat: .playerOne
        )
        #expect(lines.contains("You score 2 points."))

        let opponentLines = AnnouncementBuilder.announcements(
            before: before, after: after, move: .playCard(seat: .playerOne, card: card), listenerSeat: .playerTwo
        )
        #expect(opponentLines.contains("Opponent scores 2 points."))
    }

    @Test func sayGoIsAnnouncedForTheRightSeat() {
        let state = GameState()
        let lines = AnnouncementBuilder.announcements(
            before: state, after: state, move: .sayGo(seat: .playerTwo), listenerSeat: .playerOne
        )
        #expect(lines == ["Opponent says Go."])
    }

    // MARK: - Counting summary (replaces generic score deltas, doesn't double up)

    @Test func countingSummaryDescribesHandsAndCribWithCorrectPerspective() {
        func breakdown(_ points: Int) -> ScoreBreakdown {
            let event = ScoreEvent(kind: .fifteen, cards: [], points: points)
            return ScoreBreakdown(fifteens: [event], pairs: [], runs: [], flush: [], nobs: [])
        }

        var before = GameState(dealer: .playerTwo) // playerOne is non-dealer
        before.scores = PerSeat(playerOne: 0, playerTwo: 0)
        var after = before
        after.phase = .counting
        after.scores = PerSeat(playerOne: 8, playerTwo: 9) // 5 (dealer hand) + 4 (crib) = 9
        after.lastRoundSummary = RoundSummary(
            nonDealerHand: breakdown(8),
            dealerHand: breakdown(5),
            crib: breakdown(4),
            starter: Card(rank: .two, suit: .clubs),
            seed: Seed256(a: 1, b: 1, c: 1, d: 1)
        )

        let lines = AnnouncementBuilder.announcements(
            before: before, after: after, move: .sayGo(seat: .playerOne), listenerSeat: .playerOne
        )

        #expect(lines.contains("Your hand scores 8."))
        #expect(lines.contains("Opponent's hand scores 5."))
        #expect(lines.contains("Opponent's crib scores 4."))
        // The counting summary replaces the generic score-delta lines, not both.
        #expect(!lines.contains("You score 8 points."))
    }

    // MARK: - Game over

    @Test func gameOverAnnouncesWinLossAndSkunk() {
        var state = GameState()
        state.phase = .gameOver
        state.winner = .playerOne
        state.scores = PerSeat(playerOne: 121, playerTwo: 55)

        let winnerLines = AnnouncementBuilder.announcements(
            before: GameState(), after: state, move: .sayGo(seat: .playerOne), listenerSeat: .playerOne
        )
        #expect(winnerLines.contains("You win! Double skunk!"))

        let loserLines = AnnouncementBuilder.announcements(
            before: GameState(), after: state, move: .sayGo(seat: .playerOne), listenerSeat: .playerTwo
        )
        #expect(loserLines.contains("Opponent wins. Double skunk!"))
    }
}
