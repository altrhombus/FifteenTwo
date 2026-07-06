/// A card rank, ace-low (ace = 1 ... king = 13) for run-adjacency comparisons.
public enum Rank: Int, CaseIterable, Codable, Hashable, Sendable, Comparable {
    case ace = 1
    case two, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king

    /// Pip value for fifteens/pegging: face cards count as 10, everything else at face value.
    public var pipValue: Int { min(rawValue, 10) }

    public static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}
