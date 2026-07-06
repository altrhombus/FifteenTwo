/// The three scoring reveals at the end of a hand, in official scoring order
/// (non-dealer's hand, then dealer's hand, then dealer's crib). `dealerHand`/`crib` are
/// `nil` when the game ended before they were scored — the game stops the instant a
/// player reaches the target score, mid-count if need be.
public struct RoundSummary: Codable, Equatable, Sendable {
    public var nonDealerHand: ScoreBreakdown
    public var dealerHand: ScoreBreakdown?
    public var crib: ScoreBreakdown?
    public var starter: Card
    /// The seed this hand was dealt from — kept here (not just on `GameState.currentSeed`,
    /// which gets overwritten by the next deal) so "practice this exact hand again" can
    /// still find it after the hand is over.
    public var seed: Seed256
}
