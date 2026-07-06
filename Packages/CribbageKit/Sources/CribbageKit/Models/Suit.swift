public enum Suit: String, CaseIterable, Codable, Hashable, Sendable {
    case clubs, diamonds, hearts, spades

    /// Full word form for VoiceOver and other spoken/written contexts.
    public var spokenName: String {
        switch self {
        case .clubs: "Clubs"
        case .diamonds: "Diamonds"
        case .hearts: "Hearts"
        case .spades: "Spades"
        }
    }
}
