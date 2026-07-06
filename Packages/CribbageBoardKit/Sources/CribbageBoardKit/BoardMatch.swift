import Foundation
import CribbageKit

/// A physical-board game in progress or completed — see docs/plan.md ("Physical board
/// companion mode is intentionally a separate, much lighter model"). Shares `Ruleset`
/// (for skunk thresholds) with `CribbageKit`, but has no `Card`/`Hand`/`Deck`/`GameState`
/// dependency at all: there's no hand or crib to track here, just two running scores.
public struct BoardMatch: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    /// Always exactly 2 — see docs/plan.md ("House Rules"): 3-/4-player variants are a
    /// separate, structurally different feature, not something this model generalizes to.
    public var players: [BoardPlayer]
    public var ruleset: Ruleset
    public var startedAt: Date
    public var completedAt: Date?
    public var winnerIndex: Int?

    public init(playerOneName: String, playerTwoName: String, ruleset: Ruleset = .standard) {
        self.id = UUID()
        self.players = [BoardPlayer(name: playerOneName), BoardPlayer(name: playerTwoName)]
        self.ruleset = ruleset
        self.startedAt = Date()
        self.completedAt = nil
        self.winnerIndex = nil
    }

    public var isComplete: Bool { completedAt != nil }
}
