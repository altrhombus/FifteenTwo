#if !os(watchOS)
import Observation
import CribbageKit
import CribbageSync

/// Drives a two-device pass-and-play game over any `GameTransport` — see docs/plan.md
/// ("State & Sync"): every local move goes through the identical `GameEngine.reduce` used
/// by solo play, then out over the transport; every remote move comes back through the
/// same `reduce`. Both devices' `GameState` therefore converge exactly, with no custom
/// diffing — proven generically (without real networking) by `GameTransportConvergenceTests`
/// in CribbageSync.
///
/// Deliberately transport-agnostic: connection setup (Multipeer's host/join lobby vs.
/// SharePlay's FaceTime-activation flow) lives in the view layer, one per transport, since
/// that's genuinely different UX per transport — this class only knows "send moves,
/// receive moves," which is exactly what lets the same game logic serve both.
///
/// `GameState` still holds *both* hands in full on both devices, same as solo mode holds
/// the CPU's hand — hiding the opponent's cards is purely a rendering-layer discipline in
/// the views, never a state-layer one.
///
/// Turn ownership for moves that aren't tied to a specific seat's pegging turn follows
/// real cribbage convention, which conveniently also prevents both devices racing to
/// apply the same one-shot move twice: the dealer deals, the non-dealer cuts.
@Observable
@MainActor
public final class MultiplayerSessionController {
    public private(set) var state: GameState
    public let mySeat: Seat
    private let transport: any GameTransport
    private let ruleset: Ruleset

    public init(transport: any GameTransport, mySeat: Seat, ruleset: Ruleset = .standard) {
        self.mySeat = mySeat
        self.ruleset = ruleset
        self.state = GameState(ruleset: ruleset, dealer: .playerOne)
        self.transport = transport
        transport.onReceiveMove = { [weak self] move in self?.apply(move, isRemote: true) }
    }

    public var opponentSeat: Seat { mySeat.opponent }
    public var legalMyPlays: [Card] { GameEngine.legalPlays(for: mySeat, in: state) }

    /// Safe to call from both devices unconditionally — only actually deals if it's this
    /// device's turn to deal (see the dealer/non-dealer convention in the type doc above).
    public func dealIfMyTurn() {
        guard state.dealer == mySeat else { return }
        apply(.dealHand(seed: .random()), isRemote: false)
    }

    public func discard(_ cards: [Card]) {
        apply(.discard(seat: mySeat, cards: cards), isRemote: false)
    }

    /// Safe to call from both devices unconditionally — only the non-dealer's tap does
    /// anything, matching who cuts the deck in real cribbage.
    public func cutForStarterIfMyTurn() {
        guard state.dealer.opponent == mySeat else { return }
        apply(.cutForStarter, isRemote: false)
    }

    public func play(_ card: Card) {
        apply(.playCard(seat: mySeat, card: card), isRemote: false)
    }

    public func sayGo() {
        apply(.sayGo(seat: mySeat), isRemote: false)
    }

    // MARK: - Muggins (interactive counting)

    /// The counting decision currently owed by this device, if any.
    public var myPendingCount: PendingCount? {
        guard state.phase == .counting, let pending = state.pendingCount, pending.actor == mySeat else {
            return nil
        }
        return pending
    }

    public func claimScore(_ points: Int) {
        guard myPendingCount?.stage == .awaitingClaim else { return }
        apply(.claimScore(seat: mySeat, points: points), isRemote: false)
    }

    public func callMuggins() {
        guard myPendingCount?.stage == .awaitingMuggins else { return }
        apply(.callMuggins(seat: mySeat), isRemote: false)
    }

    public func passMuggins() {
        guard myPendingCount?.stage == .awaitingMuggins else { return }
        apply(.passMuggins(seat: mySeat), isRemote: false)
    }

    private func apply(_ move: Move, isRemote: Bool) {
        let previous = state
        state = GameEngine.reduce(state, applying: move)
        AccessibilityAnnouncer.announce(before: previous, after: state, move: move, listenerSeat: mySeat)
        if !isRemote {
            transport.send(move)
        }
    }
}
#endif
