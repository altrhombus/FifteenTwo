public struct Card: Hashable, Codable, Identifiable, Sendable {
    public let rank: Rank
    public let suit: Suit

    public init(rank: Rank, suit: Suit) {
        self.rank = rank
        self.suit = suit
    }

    /// Rank+suit uniquely identify a card within a single 52-card deck, so this is
    /// computed rather than a stored UUID — two `Card`s for the same rank/suit must
    /// remain `Equatable`-equal for scoring and solver lookups to work correctly.
    public var id: String { "\(rank.rawValue)-\(suit.rawValue)" }

    /// Full spoken form for VoiceOver and `AnnouncementBuilder`, e.g. "Five of Hearts".
    public var spokenName: String { "\(rank.spokenName) of \(suit.spokenName)" }
}
