public struct PeggingOption: Equatable, Sendable {
    /// `nil` means no legal play exists — saying "go" is the only option.
    public let card: Card?
    /// My pegging points minus the opponent's from this point onward, under optimal play
    /// by both sides — a net-margin objective, not a full-game win-probability estimate.
    public let netScore: Int
}
