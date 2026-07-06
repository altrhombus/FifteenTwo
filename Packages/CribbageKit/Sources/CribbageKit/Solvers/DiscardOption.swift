public struct DiscardOption: Equatable, Sendable {
    public let kept: [Card]
    public let discarded: [Card]
    /// Average `Scorer` total for `kept` over every possible starter — exact, not sampled.
    public let expectedHandValue: Double
    /// Average crib total over every possible starter and every possible pair of
    /// discards the opponent could have contributed — exact, not sampled.
    public let expectedCribValue: Double
    /// `expectedHandValue` plus the crib value if you're the dealer (it's your crib),
    /// minus it otherwise (it's the opponent's).
    public let netExpectedValue: Double
}
