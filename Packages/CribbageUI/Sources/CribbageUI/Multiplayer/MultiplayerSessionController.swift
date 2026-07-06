#if !os(watchOS)
import Observation
import CribbageKit
import CribbageSync
import MultipeerConnectivity

public enum MultiplayerConnectionState: Equatable, Sendable {
    case notConnected
    case hosting
    case browsing
    case connected(peerName: String)
}

/// Drives a two-device pass-and-play game over Multipeer — see docs/plan.md ("State &
/// Sync"): every local move goes through the identical `GameEngine.reduce` used by solo
/// play, then out over `GameTransport`; every remote move comes back through the same
/// `reduce`. Both devices' `GameState` therefore converge exactly, with no custom diffing
/// — proven generically (without real networking) by `GameTransportConvergenceTests` in
/// CribbageSync.
///
/// `GameState` still holds *both* hands in full on both devices, same as solo mode holds
/// the CPU's hand — hiding the opponent's cards is purely a rendering-layer discipline in
/// `MultiplayerGameView`, never a state-layer one.
///
/// Turn ownership for moves that aren't tied to a specific seat's pegging turn follows
/// real cribbage convention, which conveniently also prevents both devices racing to
/// apply the same one-shot move twice: the dealer deals, the non-dealer cuts.
@Observable
@MainActor
public final class MultiplayerSessionController {
    public private(set) var state: GameState
    public let mySeat: Seat
    public private(set) var connectionState: MultiplayerConnectionState = .notConnected
    private let transport: MultipeerGameTransport
    private let ruleset: Ruleset

    public init(displayName: String, mySeat: Seat, ruleset: Ruleset = .standard) {
        self.mySeat = mySeat
        self.ruleset = ruleset
        self.state = GameState(ruleset: ruleset, dealer: .playerOne)
        self.transport = MultipeerGameTransport(displayName: displayName)

        transport.onReceiveMove = { [weak self] move in self?.apply(move, isRemote: true) }
        transport.onConnectedPeersChanged = { [weak self] peerNames in
            guard let self else { return }
            connectionState = peerNames.first.map { .connected(peerName: $0) } ?? .notConnected
        }
    }

    public var opponentSeat: Seat { mySeat.opponent }
    public var legalMyPlays: [Card] { GameEngine.legalPlays(for: mySeat, in: state) }

    /// Exposed only so `PeerBrowserView` can hand these straight to the system's
    /// `MCBrowserViewController` — CribbageUI never talks to `MCSession` directly itself.
    public var browser: MCNearbyServiceBrowser { transport.browser }
    public var session: MCSession { transport.session }

    public func startHosting() {
        connectionState = .hosting
        transport.startHosting()
    }

    public func startBrowsing() {
        connectionState = .browsing
    }

    public func stopBrowsing() {
        transport.stopBrowsing()
    }

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

    public func disconnect() {
        transport.disconnect()
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
