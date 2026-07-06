/// See docs/plan.md ("CPU difficulty tiers, not just optimal"): an always-perfect
/// opponent is discouraging for a player still learning strategy. `expert` is the exact
/// solver output; the easier tiers sample from the solver's own top-*k* ranked options,
/// so even "easy" play is grounded in the real analysis rather than a separate heuristic.
public enum CPUDifficulty: String, Codable, Sendable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case expert

    public var id: String { rawValue }

    var discardTopK: Int {
        switch self {
        case .beginner: 8
        case .intermediate: 3
        case .expert: 1
        }
    }

    var peggingTopK: Int {
        switch self {
        case .beginner: 4
        case .intermediate: 2
        case .expert: 1
        }
    }

    var peggingSampleCount: Int {
        switch self {
        case .beginner: 40
        case .intermediate: 80
        case .expert: 150
        }
    }
}
