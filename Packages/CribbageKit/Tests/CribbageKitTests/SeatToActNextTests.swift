import Testing
@testable import CribbageKit

/// `GameEngine.seatToActNext` exists specifically for Game Center turn-based matches (see
/// its doc comment): a strict, serialized "whose turn is it" answer for every phase, since
/// a store-and-forward match can only ever have one active participant at a time — unlike
/// solo/live multiplayer, where discarding allows both seats to act "simultaneously."
struct SeatToActNextTests {
    @Test func dealingPhaseIsTheDealersTurn() {
        var state = GameState(dealer: .playerTwo)
        state.phase = .dealing
        #expect(GameEngine.seatToActNext(in: state) == .playerTwo)
    }

    @Test func discardingIsTheNonDealersTurnWhenNeitherHasDiscarded() {
        var state = GameState(dealer: .playerOne)
        state.phase = .discarding
        state.hands = PerSeat(playerOne: Array(repeating: Card(rank: .ace, suit: .clubs), count: 6),
                               playerTwo: Array(repeating: Card(rank: .ace, suit: .clubs), count: 6))
        #expect(GameEngine.seatToActNext(in: state) == .playerTwo) // non-dealer
    }

    @Test func discardingIsTheDealersTurnAfterTheNonDealerHasDiscarded() {
        var state = GameState(dealer: .playerOne)
        state.phase = .discarding
        state.hands = PerSeat(playerOne: Array(repeating: Card(rank: .ace, suit: .clubs), count: 6),
                               playerTwo: Array(repeating: Card(rank: .ace, suit: .clubs), count: 4))
        #expect(GameEngine.seatToActNext(in: state) == .playerOne) // dealer, since non-dealer (two) already discarded
    }

    @Test func cutStarterIsTheNonDealersTurn() {
        var state = GameState(dealer: .playerTwo)
        state.phase = .cutStarter
        #expect(GameEngine.seatToActNext(in: state) == .playerOne)
    }

    @Test func peggingUsesTurnToActDirectly() {
        var state = GameState()
        state.phase = .pegging
        state.turnToAct = .playerTwo
        #expect(GameEngine.seatToActNext(in: state) == .playerTwo)
    }

    @Test func countingIsTheOutgoingDealersTurnToDealNext() {
        var state = GameState(dealer: .playerOne)
        state.phase = .counting
        #expect(GameEngine.seatToActNext(in: state) == .playerOne)
    }

    @Test func gameOverHasNoNextActor() {
        var state = GameState()
        state.phase = .gameOver
        #expect(GameEngine.seatToActNext(in: state) == nil)
    }
}
