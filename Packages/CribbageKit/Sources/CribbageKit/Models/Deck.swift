public enum Deck {
    /// All 52 cards of a standard deck, in a fixed (unshuffled) order. Shuffling is a
    /// later concern (see docs/plan.md, "RNG & Fairness") — this is just the card set.
    public static let standard52: [Card] = Suit.allCases.flatMap { suit in
        Rank.allCases.map { rank in Card(rank: rank, suit: suit) }
    }
}
