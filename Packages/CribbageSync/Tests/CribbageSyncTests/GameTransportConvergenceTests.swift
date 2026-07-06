import Testing
import CribbageKit
@testable import CribbageSync

/// A same-process, no-networking stand-in for `MultipeerGameTransport` — lets the sync
/// *contract* (apply locally, send, receive, apply remotely) be tested without real
/// Multipeer, which needs physical hardware and isn't something CI or this test suite can
/// exercise.
@MainActor
private final class MockGameTransport: GameTransport {
    var onReceiveMove: ((Move) -> Void)?
    var peer: MockGameTransport?

    func send(_ move: Move) {
        peer?.onReceiveMove?(move)
    }
}

@MainActor
struct GameTransportConvergenceTests {
    /// The whole premise of docs/plan.md's "State & Sync" section: two peers starting from
    /// the same seeded state, each applying the same ordered `Move`s through the identical
    /// pure `GameEngine.reduce`, converge to identical `GameState` with no custom diffing.
    /// This is the property that makes Multipeer (and later SharePlay) "just another
    /// transport" rather than a second implementation of the game.
    @Test func twoPeersConvergeToIdenticalStateAfterAFullHand() {
        let hostTransport = MockGameTransport()
        let joinerTransport = MockGameTransport()
        hostTransport.peer = joinerTransport
        joinerTransport.peer = hostTransport

        var hostState = GameState()
        var joinerState = GameState()
        hostTransport.onReceiveMove = { hostState = GameEngine.reduce(hostState, applying: $0) }
        joinerTransport.onReceiveMove = { joinerState = GameEngine.reduce(joinerState, applying: $0) }

        func applyOnHost(_ move: Move) {
            hostState = GameEngine.reduce(hostState, applying: move)
            hostTransport.send(move)
        }
        func applyOnJoiner(_ move: Move) {
            joinerState = GameEngine.reduce(joinerState, applying: move)
            joinerTransport.send(move)
        }

        applyOnHost(.dealHand(seed: .random()))
        #expect(hostState == joinerState)

        applyOnHost(.discard(seat: .playerOne, cards: Array(hostState.hands[.playerOne].prefix(2))))
        #expect(hostState == joinerState)
        applyOnJoiner(.discard(seat: .playerTwo, cards: Array(joinerState.hands[.playerTwo].prefix(2))))
        #expect(hostState == joinerState)

        applyOnHost(.cutForStarter)
        #expect(hostState == joinerState)
        #expect(hostState.phase == .pegging)

        while hostState.phase == .pegging {
            let toAct = hostState.turnToAct
            let apply = toAct == .playerOne ? applyOnHost : applyOnJoiner
            let legal = GameEngine.legalPlays(for: toAct, in: hostState)
            if let card = legal.first {
                apply(.playCard(seat: toAct, card: card))
            } else {
                apply(.sayGo(seat: toAct))
            }
            #expect(hostState == joinerState)
        }

        #expect(hostState.lastRoundSummary != nil)
        #expect(hostState == joinerState)
    }

    /// A move sent by one peer must never be echoed back to itself — `send` only reaches
    /// the *other* side.
    @Test func sendingAMoveDoesNotLoopBackToTheSender() {
        let transport = MockGameTransport()
        var receivedCount = 0
        transport.onReceiveMove = { _ in receivedCount += 1 }
        transport.send(.cutForStarter)
        #expect(receivedCount == 0)
    }
}
