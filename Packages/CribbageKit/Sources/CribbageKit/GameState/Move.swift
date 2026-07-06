/// Every state transition, human or CPU, local or networked, goes through one of these —
/// see docs/plan.md ("State & Sync"): the same `Move` stream, applied through the same
/// `GameEngine.reduce`, is what lets solo play, Multipeer, and SharePlay share one engine.
public enum Move: Codable, Equatable, Sendable {
    /// Shuffles (using `seed`) and deals a fresh 6-card hand to each seat. Also used to
    /// start the very first hand of a game. If the previous phase was `.counting`, the
    /// dealer alternates. The seed is decided by whoever issues this move, not by
    /// `GameEngine.reduce` itself — the reducer must stay a pure function of its inputs
    /// so networked peers replaying the same move stream deal identically.
    case dealHand(seed: Seed256)
    /// Discards exactly 2 cards from `seat`'s hand to the crib.
    case discard(seat: Seat, cards: [Card])
    /// Reveals the starter card from the remaining deck; applies "his heels" if it's a jack.
    case cutForStarter
    /// Plays a single card during pegging.
    case playCard(seat: Seat, card: Card)
    /// Declares that `seat` has no legal play remaining at the current count.
    case sayGo(seat: Seat)
}
