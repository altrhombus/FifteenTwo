/// A fixed identity for one of the two sides of a cribbage game. `Seat` is deliberately
/// agnostic to who's actually playing it (human, CPU, remote peer) — that mapping lives
/// in whatever's driving the engine (`GameSessionController` and friends), not here.
public enum Seat: String, Codable, Hashable, Sendable, CaseIterable {
    case playerOne, playerTwo

    public var opponent: Seat { self == .playerOne ? .playerTwo : .playerOne }
}

/// A simple two-slot container keyed by `Seat`, used instead of `Dictionary<Seat, _>`
/// so `GameState` round-trips through `Codable` (and therefore `MultipeerGameTransport`/
/// `GroupActivityGameTransport` later) without depending on Dictionary's less predictable
/// keyed-vs-array JSON encoding for non-string/int keys.
public struct PerSeat<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var playerOne: Value
    public var playerTwo: Value

    public init(playerOne: Value, playerTwo: Value) {
        self.playerOne = playerOne
        self.playerTwo = playerTwo
    }

    public subscript(seat: Seat) -> Value {
        get { seat == .playerOne ? playerOne : playerTwo }
        set {
            switch seat {
            case .playerOne: playerOne = newValue
            case .playerTwo: playerTwo = newValue
            }
        }
    }
}
