/// Every state transition, human or CPU, local or networked, goes through one of these —
/// see docs/plan.md ("State & Sync"): the same `Move` stream, applied through the same
/// `GameEngine.reduce`, is what lets solo play, Multipeer, and SharePlay share one engine.
public enum Move: Codable, Equatable, Sendable {
    /// Shuffles and deals a fresh 6-card hand to each seat. Also used to start the very
    /// first hand of a game. If the previous phase was `.counting`, the dealer alternates.
    case dealHand
    /// Discards exactly 2 cards from `seat`'s hand to the crib.
    case discard(seat: Seat, cards: [Card])
    /// Reveals the starter card from the remaining deck; applies "his heels" if it's a jack.
    case cutForStarter
    /// Plays a single card during pegging.
    case playCard(seat: Seat, card: Card)
    /// Declares that `seat` has no legal play remaining at the current count.
    case sayGo(seat: Seat)
}
