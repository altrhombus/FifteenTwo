/// One side of a physical-board match. A real cribbage board uses two pegs per player —
/// the front peg marks the current total, the back peg marks the total before the most
/// recent score (so players can recount the gap between them if there's a dispute).
/// `scoreHistory` captures the same information more simply: the front/back pegs are
/// just the last two cumulative totals.
public struct BoardPlayer: Codable, Equatable, Sendable {
    public var name: String
    public var scoreHistory: [Int]

    public init(name: String, scoreHistory: [Int] = []) {
        self.name = name
        self.scoreHistory = scoreHistory
    }

    /// The front peg: the current total.
    public var currentScore: Int { scoreHistory.last ?? 0 }

    /// The back peg: the total before the most recent score, for the recount-the-gap
    /// convention — 0 if there's no prior score yet.
    public var previousScore: Int { scoreHistory.dropLast().last ?? 0 }
}
