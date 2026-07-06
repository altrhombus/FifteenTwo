import CribbageKit

/// Transport-agnostic move sync — see docs/plan.md ("State & Sync"): "MultipeerGameTransport
/// wraps MCSession... GroupActivityGameTransport wraps GroupSessionMessenger... same
/// protocol, same reducer, no rearchitecture between the two." Both conformances only need
/// to move `Move` values between peers; everything else (turn ownership, hidden-hand
/// rendering discipline, applying moves through `GameEngine.reduce`) lives one layer up in
/// whatever's driving the engine, not here.
@MainActor
public protocol GameTransport: AnyObject {
    /// Fires whenever a `Move` arrives from a peer, already decoded.
    var onReceiveMove: ((Move) -> Void)? { get set }

    /// Sends a locally-applied move to connected peer(s).
    func send(_ move: Move)
}
